# mediahub/web.py
from __future__ import annotations
from pathlib import Path

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates

from .parse import parse_release
from .hardlink import media_files, hardlink

_TEMPLATES = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))


def _match(facet_value, wanted) -> bool:
    if not wanted:
        return True
    return (facet_value or "").lower() == wanted.lower()


_CATEGORY_RANGES = {
    "movies": (2000, 2999),
    "audio": (3000, 3999),
    "tv": (5000, 5999),
    "xxx": (6000, 6999),
}
_SORT_KEYS = {
    "seeders": lambda x: x["r"].seeders,
    "size": lambda x: x["r"].size,
    "date": lambda x: x["r"].publish_date or "",
    "title": lambda x: x["r"].title.lower(),
}


def _has(values, wanted) -> bool:
    if not wanted:
        return True
    return wanted.lower() in [v.lower() for v in values]


def _in_category(cat_ids, wanted) -> bool:
    if not wanted:
        return True
    rng = _CATEGORY_RANGES.get(wanted.lower())
    if rng is None:
        return True
    lo, hi = rng
    return any(lo <= c <= hi for c in cat_ids)


def create_app(config, prowlarr, transmission, store, parser=parse_release) -> FastAPI:
    app = FastAPI()
    templates = _TEMPLATES

    @app.get("/", response_class=HTMLResponse)
    def index(request: Request):
        return templates.TemplateResponse(request, "search.html")

    @app.get("/api/search", response_class=HTMLResponse)
    def search(request: Request, q: str, resolution: str = "", source: str = "",
               codec: str = "", hdr: str = "", audio: str = "", group: str = "",
               site: str = "", category: str = "", min_seeders: int = 0,
               min_size_gb: float = 0.0, sort: str = "seeders", order: str = "desc"):
        try:
            releases = prowlarr.search(q)
        except Exception as e:
            return HTMLResponse(f"<p style='color:red'>search failed: {e}</p>")
        rows = []
        for r in releases:
            f = parser(r.title)
            if not _match(f.resolution, resolution):
                continue
            if not _match(f.source, source):
                continue
            if not _match(f.codec, codec):
                continue
            if not _has(f.hdr, hdr):
                continue
            if not _has(f.audio, audio):
                continue
            if group and group.lower() not in (f.group or "").lower():
                continue
            if site and site.lower() not in r.indexer.lower():
                continue
            if not _in_category(r.categories, category):
                continue
            if r.seeders < min_seeders:
                continue
            if min_size_gb and r.size < min_size_gb * (1024 ** 3):
                continue
            rows.append({"r": r, "f": f})
        keyfn = _SORT_KEYS.get(sort, _SORT_KEYS["seeders"])
        rows.sort(key=keyfn, reverse=(order != "asc"))
        return templates.TemplateResponse(request, "results.html", context={"rows": rows})

    @app.post("/api/grab")
    def grab(downloadUrl: str = Form(...), title: str = Form(...)):
        try:
            data = prowlarr.fetch_torrent(downloadUrl)
            h = transmission.add_torrent(data, config.downloads_dir)
        except Exception as e:
            return JSONResponse({"ok": False, "error": str(e)}, status_code=502)
        return JSONResponse({"ok": True, "hash": h, "title": title})

    @app.get("/review", response_class=HTMLResponse)
    def review(request: Request):
        return templates.TemplateResponse(
            request, "review.html", context={"items": store.list_pending()}
        )

    @app.post("/api/place")
    def place(id: int = Form(...), dest: str = Form(...)):
        item = store.get(id)
        if item is None:
            return JSONResponse({"ok": False, "error": "not found"}, status_code=404)
        media_root = Path(config.media_root).resolve()
        dest_path = Path(dest).resolve()
        if not dest_path.is_relative_to(media_root):
            return JSONResponse(
                {"ok": False, "error": "dest outside media_root"}, status_code=400
            )
        try:
            for f in media_files(Path(item.src_dir)):
                hardlink(f, dest_path / f.name)
        except (FileExistsError, RuntimeError, OSError) as e:
            return JSONResponse({"ok": False, "error": str(e)}, status_code=422)
        store.mark_done(id)
        return RedirectResponse("/review", status_code=303)

    return app
