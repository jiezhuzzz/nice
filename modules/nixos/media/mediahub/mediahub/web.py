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


def create_app(config, prowlarr, transmission, store, parser=parse_release) -> FastAPI:
    app = FastAPI()
    templates = _TEMPLATES

    @app.get("/", response_class=HTMLResponse)
    def index(request: Request):
        return templates.TemplateResponse(request, "search.html")

    @app.get("/api/search", response_class=HTMLResponse)
    def search(request: Request, q: str, resolution: str = "", source: str = "",
               group: str = "", min_seeders: int = 0):
        rows = []
        for r in prowlarr.search(q):
            f = parser(r.title)
            if not _match(f.resolution, resolution):
                continue
            if not _match(f.source, source):
                continue
            if group and group.lower() not in (f.group or "").lower():
                continue
            if r.seeders < min_seeders:
                continue
            rows.append({"r": r, "f": f})
        rows.sort(key=lambda x: x["r"].seeders, reverse=True)
        return templates.TemplateResponse(request, "results.html", context={"rows": rows})

    @app.post("/api/grab")
    def grab(downloadUrl: str = Form(...), title: str = Form(...)):
        data = prowlarr.fetch_torrent(downloadUrl)
        h = transmission.add_torrent(data, config.downloads_dir)
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
        for f in media_files(Path(item.src_dir)):
            hardlink(f, Path(dest) / f.name)
        store.mark_done(id)
        return RedirectResponse("/review", status_code=303)

    return app
