# Media Search + Agent Filing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `mediahub` — a thin faceted PT-search/grab web app backed by a headless Prowlarr, plus a Transmission completion-hook filer that runs Claude Code (headless) to hardlink finished downloads into the Jellyfin library.

**Architecture:** Two units sharing a SQLite review table. `mediahub-web` (FastAPI + htmx) proxies Prowlarr search, parses release titles into filter facets, and grabs to Transmission via RPC. On download completion, Transmission's `script-torrent-done` runs `mediahub-file` **as the `transmission` user**, which invokes `claude -p` (allow-listed to `Read`/`ls`/`stat`/`mkdir`/`ln`) to hardlink into `/tank/media`; ambiguous releases go to the review queue.

**Tech Stack:** Python 3.12 (FastAPI, uvicorn, httpx, guessit, jinja2), SQLite, `uv` for dev/test, Nix (`buildPythonApplication`) for packaging, NixOS modules (Prowlarr, systemd, Transmission hook), Claude Code CLI.

**Spec:** `docs/superpowers/specs/2026-07-04-media-search-agent-filing-design.md`

---

## File structure

```
modules/nixos/media/
  prowlarr.nix                    # NixOS: headless Prowlarr (Phase 2)
  mediahub.nix                    # NixOS: package app + systemd web service + install filer (Phase 2)
  mediahub/                       # in-repo Python source
    pyproject.toml
    mediahub/
      __init__.py
      config.py                   # env config
      parse.py                    # release title -> filter facets
      hardlink.py                 # os.link helpers (used by /api/place)
      store.py                    # SQLite review queue
      prowlarr.py                 # Prowlarr search + torrent fetch client
      transmission.py             # Transmission RPC client
      filer.py                    # completion filer -> Claude Code
      web.py                      # FastAPI app factory + routes
      cli.py                      # console entry points
      templates/
        search.html
        results.html
        review.html
    tests/
      test_parse.py
      test_hardlink.py
      test_store.py
      test_prowlarr.py
      test_transmission.py
      test_filer.py
      test_web.py
```

Convention notes for the implementer:
- Run Python via `uv` only (never bare `python`/`pip`). Tests: `uv run pytest ...`.
- Commit after each task with Conventional Commits (`feat(mediahub): …`, scope `mediahub` for app, `nixos`/`media` for deploy). Branch is `main` (repo commits directly to main).
- Nix files are formatted with `alejandra` via `nix fmt`.

---

# Phase 1 — the `mediahub` Python application

## Task 1: Scaffold the project

**Files:**
- Create: `modules/nixos/media/mediahub/pyproject.toml`
- Create: `modules/nixos/media/mediahub/mediahub/__init__.py`
- Create: `modules/nixos/media/mediahub/tests/__init__.py`

- [ ] **Step 1: Write `pyproject.toml`**

```toml
[project]
name = "mediahub"
version = "0.1.0"
description = "Faceted PT search/grab + agent filing"
requires-python = ">=3.12"
dependencies = [
    "fastapi",
    "uvicorn",
    "httpx",
    "guessit",
    "jinja2",
    "python-multipart",
]

[project.optional-dependencies]
dev = ["pytest", "respx"]

[project.scripts]
mediahub-web = "mediahub.cli:web"
mediahub-file = "mediahub.cli:file_done"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["mediahub"]
```

- [ ] **Step 2: Create empty package + test package**

`modules/nixos/media/mediahub/mediahub/__init__.py`:
```python
__version__ = "0.1.0"
```
`modules/nixos/media/mediahub/tests/__init__.py`: (empty file)

- [ ] **Step 3: Verify the package imports**

Run (from `modules/nixos/media/mediahub`): `uv run python -c "import mediahub; print(mediahub.__version__)"`
Expected: prints `0.1.0` (uv builds an ephemeral venv from pyproject).

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/media/mediahub/pyproject.toml modules/nixos/media/mediahub/mediahub/__init__.py modules/nixos/media/mediahub/tests/__init__.py
git commit -m "feat(mediahub): scaffold python project"
```

---

## Task 2: `config.py` — environment configuration

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/config.py`
- Test: `modules/nixos/media/mediahub/tests/test_config.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_config.py
from mediahub.config import Config

def test_from_env_defaults(monkeypatch):
    for k in ("PROWLARR_URL","PROWLARR_API_KEY","TRANSMISSION_RPC_URL",
              "MEDIA_ROOT","DOWNLOADS_DIR","MEDIAHUB_DB"):
        monkeypatch.delenv(k, raising=False)
    c = Config.from_env()
    assert c.prowlarr_url == "http://127.0.0.1:9696"
    assert c.media_root == "/tank/media"
    assert c.db_path == "/var/lib/mediahub/review.db"

def test_from_env_overrides(monkeypatch):
    monkeypatch.setenv("PROWLARR_API_KEY", "abc123")
    monkeypatch.setenv("MEDIA_ROOT", "/mnt/x")
    c = Config.from_env()
    assert c.prowlarr_api_key == "abc123"
    assert c.media_root == "/mnt/x"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_config.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.config`.

- [ ] **Step 3: Write `config.py`**

```python
# mediahub/config.py
from __future__ import annotations
import os
from dataclasses import dataclass


@dataclass
class Config:
    prowlarr_url: str
    prowlarr_api_key: str
    transmission_rpc_url: str
    media_root: str
    downloads_dir: str
    db_path: str

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            prowlarr_url=os.environ.get("PROWLARR_URL", "http://127.0.0.1:9696"),
            prowlarr_api_key=os.environ.get("PROWLARR_API_KEY", ""),
            transmission_rpc_url=os.environ.get(
                "TRANSMISSION_RPC_URL", "http://127.0.0.1:9091/transmission/rpc"
            ),
            media_root=os.environ.get("MEDIA_ROOT", "/tank/media"),
            downloads_dir=os.environ.get("DOWNLOADS_DIR", "/tank/media/downloads"),
            db_path=os.environ.get("MEDIAHUB_DB", "/var/lib/mediahub/review.db"),
        )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_config.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/config.py modules/nixos/media/mediahub/tests/test_config.py
git commit -m "feat(mediahub): add env config"
```

---

## Task 3: `parse.py` — release title → filter facets

This is the core value-add over Prowlarr's UI. `guessit` handles title/year/season/type;
a regex layer over the raw title extracts resolution/source/codec/hdr/audio/group robustly
for messy CN-PT names.

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/parse.py`
- Test: `modules/nixos/media/mediahub/tests/test_parse.py`

- [ ] **Step 1: Write the failing test (seeded with real releases)**

```python
# tests/test_parse.py
from mediahub.parse import parse_release


def test_project_hail_mary():
    f = parse_release(
        "挽救计划.Project.Hail.Mary.2026.2160p.WEB-DL.DDP5.1.Atmos.H265.HDR.DV-DIY@HDSWEB"
    )
    assert f.resolution == "2160p"
    assert f.source == "WEB-DL"
    assert f.codec == "H.265"
    assert "HDR" in f.hdr
    assert "DV" in f.hdr
    assert "Atmos" in f.audio
    assert f.year == 2026
    assert f.group is not None and "HDSWEB" in f.group


def test_bleach_s2_bdrip():
    f = parse_release("[2023][Bleach Sennen Kessen Hen S2][BDRIP][1080P][14-26+SP]")
    assert f.resolution == "1080p"
    assert f.source == "BDRip"
    assert f.season == 2


def test_yumi_s02_webdl():
    f = parse_release(
        "[柔美的细胞小将 第二季].Yumi's.Cells.2022.S02.Complete.1080p.IQ.WEB-DL.H264.AAC-UBWEB"
    )
    assert f.resolution == "1080p"
    assert f.source == "WEB-DL"
    assert f.codec == "H.264"
    assert "AAC" in f.audio
    assert f.season == 2
    assert f.group == "UBWEB"


def test_jav_code_has_no_quality():
    f = parse_release("JUX-455")
    assert f.resolution is None
    assert f.source is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_parse.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.parse`.

- [ ] **Step 3: Write `parse.py`**

```python
# mediahub/parse.py
from __future__ import annotations
import re
from dataclasses import dataclass, field

from guessit import guessit

_RES = [(re.compile(r, re.I), n) for r, n in [
    (r"2160p|\b4k\b|\buhd\b", "2160p"),
    (r"1080p", "1080p"),
    (r"720p", "720p"),
    (r"480p", "480p"),
]]
_SOURCE = [(re.compile(r, re.I), n) for r, n in [
    (r"remux", "Remux"),
    (r"web[-. ]?dl", "WEB-DL"),
    (r"web[-. ]?rip", "WEBRip"),
    (r"bd[-. ]?rip", "BDRip"),
    (r"blu[-. ]?ray|bdmv|\bbd\b", "BluRay"),
    (r"hdtv", "HDTV"),
    (r"hd[-. ]?rip", "HDRip"),
]]
_CODEC = [(re.compile(r, re.I), n) for r, n in [
    (r"h[.\- ]?265|x265|hevc", "H.265"),
    (r"h[.\- ]?264|x264|\bavc\b", "H.264"),
    (r"av1", "AV1"),
]]
_HDR = [(re.compile(r, re.I), n) for r, n in [
    (r"hdr10\+|hdr10|(?<![a-z])hdr(?![a-z])", "HDR"),
    (r"dolby[. ]?vision|dovi|(?<![a-z])dv(?![a-z])", "DV"),
]]
_AUDIO = [(re.compile(r, re.I), n) for r, n in [
    (r"atmos", "Atmos"),
    (r"true[-. ]?hd", "TrueHD"),
    (r"dts[-. ]?hd", "DTS-HD"),
    (r"(?<![a-z])dts(?![a-z])", "DTS"),
    (r"ddp|dd\+|e[-. ]?ac3", "DDP"),
    (r"(?<![a-z])ac3(?![a-z])|(?<![a-z])dd(?![a-z0-9])", "DD"),
    (r"(?<![a-z])aac(?![a-z])", "AAC"),
    (r"flac", "FLAC"),
]]
# Trailing release group: "...-UBWEB" / "...-DIY@HDSWEB"
_GROUP_TAIL = re.compile(r"[-](?P<g>[A-Za-z0-9]+(?:@[A-Za-z0-9]+)?)\s*$")


@dataclass
class Facets:
    title: str | None
    year: int | None
    kind: str | None            # guessit 'type': movie / episode / ...
    season: int | None
    resolution: str | None
    source: str | None
    codec: str | None
    hdr: list[str] = field(default_factory=list)
    audio: list[str] = field(default_factory=list)
    group: str | None = None


def _first(patterns, text):
    for rx, name in patterns:
        if rx.search(text):
            return name
    return None


def _all(patterns, text):
    out = []
    for rx, name in patterns:
        if rx.search(text) and name not in out:
            out.append(name)
    return out


def parse_release(title: str) -> Facets:
    g = guessit(title)
    season = g.get("season")
    if isinstance(season, list):
        season = season[0]
    year = g.get("year")
    group = g.get("release_group")
    m = _GROUP_TAIL.search(title)
    if m:
        group = m.group("g")
    return Facets(
        title=g.get("title"),
        year=int(year) if year else None,
        kind=g.get("type"),
        season=int(season) if season is not None else None,
        resolution=_first(_RES, title),
        source=_first(_SOURCE, title),
        codec=_first(_CODEC, title),
        hdr=_all(_HDR, title),
        audio=_all(_AUDIO, title),
        group=group,
    )
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_parse.py -v`
Expected: PASS (4 passed). If `test_yumi_s02_webdl` group assertion fails because guessit's release_group differs, the `_GROUP_TAIL` regex fallback (matching trailing `-UBWEB`) is what makes `group == "UBWEB"`; confirm the regex ran.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/parse.py modules/nixos/media/mediahub/tests/test_parse.py
git commit -m "feat(mediahub): parse release titles into filter facets"
```

---

## Task 4: `hardlink.py` — media-file hardlink helpers

Used by `/api/place` (deterministic user-driven placement). The filer's own linking is done by the agent.

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/hardlink.py`
- Test: `modules/nixos/media/mediahub/tests/test_hardlink.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_hardlink.py
import os
from pathlib import Path
import pytest
from mediahub.hardlink import media_files, hardlink


def test_media_files_filters(tmp_path):
    (tmp_path / "a.mkv").write_text("x")
    (tmp_path / "b.nfo").write_text("x")
    sub = tmp_path / "extras"; sub.mkdir()
    (sub / "c.mp4").write_text("x")
    names = {p.name for p in media_files(tmp_path)}
    assert names == {"a.mkv", "c.mp4"}


def test_hardlink_creates_second_link(tmp_path):
    src = tmp_path / "a.mkv"; src.write_text("data")
    dest = tmp_path / "lib" / "a.mkv"
    assert hardlink(src, dest) is True
    assert dest.exists()
    assert os.stat(dest).st_nlink == 2
    assert os.stat(src).st_ino == os.stat(dest).st_ino


def test_hardlink_idempotent(tmp_path):
    src = tmp_path / "a.mkv"; src.write_text("data")
    dest = tmp_path / "lib" / "a.mkv"
    hardlink(src, dest)
    assert hardlink(src, dest) is False  # already linked, no error


def test_hardlink_collision_raises(tmp_path):
    src = tmp_path / "a.mkv"; src.write_text("data")
    dest = tmp_path / "lib" / "a.mkv"; dest.parent.mkdir(parents=True)
    dest.write_text("different")
    with pytest.raises(FileExistsError):
        hardlink(src, dest)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_hardlink.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.hardlink`.

- [ ] **Step 3: Write `hardlink.py`**

```python
# mediahub/hardlink.py
from __future__ import annotations
import errno
import os
from pathlib import Path

MEDIA_EXTS = {
    ".mkv", ".mp4", ".avi", ".m2ts", ".ts", ".mov", ".wmv", ".iso",
    ".flac", ".mp3", ".m4a", ".wav", ".dts", ".ape",
}


def media_files(root: Path) -> list[Path]:
    root = Path(root)
    if root.is_file():
        return [root] if root.suffix.lower() in MEDIA_EXTS else []
    return sorted(
        p for p in root.rglob("*")
        if p.is_file() and p.suffix.lower() in MEDIA_EXTS
    )


def hardlink(src: Path, dest: Path) -> bool:
    """Hardlink src -> dest. Returns True if created, False if already the same
    inode (idempotent). Raises FileExistsError on a differing collision and
    RuntimeError on a cross-device (EXDEV) attempt."""
    src, dest = Path(src), Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        if os.stat(dest).st_ino == os.stat(src).st_ino:
            return False
        raise FileExistsError(f"{dest} exists and differs from {src}")
    try:
        os.link(src, dest)
    except OSError as e:
        if e.errno == errno.EXDEV:
            raise RuntimeError(f"cross-device link {src} -> {dest}") from e
        raise
    return True
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_hardlink.py -v`
Expected: PASS (4 passed).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/hardlink.py modules/nixos/media/mediahub/tests/test_hardlink.py
git commit -m "feat(mediahub): add media-file hardlink helpers"
```

---

## Task 5: `store.py` — SQLite review queue

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/store.py`
- Test: `modules/nixos/media/mediahub/tests/test_store.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_store.py
from mediahub.store import ReviewStore


def test_add_and_list(tmp_path):
    s = ReviewStore(tmp_path / "r.db")
    rid = s.add("hash1", "Some.Release", "/dl/Some.Release", "movie",
                "/tank/media/movies/Some (2024)", "unknown year")
    assert isinstance(rid, int)
    pending = s.list_pending()
    assert len(pending) == 1
    assert pending[0].hash == "hash1"
    assert pending[0].suggested_kind == "movie"
    assert pending[0].status == "pending"


def test_get_and_mark_done(tmp_path):
    s = ReviewStore(tmp_path / "r.db")
    rid = s.add("h", "n", "/dl/n", None, None, "reason")
    item = s.get(rid)
    assert item.name == "n"
    s.mark_done(rid)
    assert s.list_pending() == []
    assert s.get(rid).status == "done"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_store.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.store`.

- [ ] **Step 3: Write `store.py`**

```python
# mediahub/store.py
from __future__ import annotations
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Review:
    id: int
    hash: str
    name: str
    src_dir: str
    suggested_kind: str | None
    suggested_dest: str | None
    reason: str
    created_at: float
    status: str


class ReviewStore:
    def __init__(self, db_path):
        self.db_path = str(db_path)
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        with self._conn() as c:
            c.execute(
                """CREATE TABLE IF NOT EXISTS review(
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    hash TEXT, name TEXT, src_dir TEXT,
                    suggested_kind TEXT, suggested_dest TEXT, reason TEXT,
                    created_at REAL, status TEXT NOT NULL DEFAULT 'pending')"""
            )

    def _conn(self):
        c = sqlite3.connect(self.db_path)
        c.row_factory = sqlite3.Row
        return c

    def add(self, hash, name, src_dir, suggested_kind, suggested_dest, reason) -> int:
        with self._conn() as c:
            cur = c.execute(
                """INSERT INTO review(hash,name,src_dir,suggested_kind,
                   suggested_dest,reason,created_at,status)
                   VALUES(?,?,?,?,?,?,?,'pending')""",
                (hash, name, src_dir, suggested_kind, suggested_dest, reason, time.time()),
            )
            return cur.lastrowid

    def _row(self, r) -> Review:
        return Review(**{k: r[k] for k in r.keys()})

    def list_pending(self) -> list[Review]:
        with self._conn() as c:
            rows = c.execute(
                "SELECT * FROM review WHERE status='pending' ORDER BY created_at DESC"
            ).fetchall()
        return [self._row(r) for r in rows]

    def get(self, rid) -> Review | None:
        with self._conn() as c:
            r = c.execute("SELECT * FROM review WHERE id=?", (rid,)).fetchone()
        return self._row(r) if r else None

    def mark_done(self, rid) -> None:
        with self._conn() as c:
            c.execute("UPDATE review SET status='done' WHERE id=?", (rid,))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_store.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/store.py modules/nixos/media/mediahub/tests/test_store.py
git commit -m "feat(mediahub): add sqlite review store"
```

---

## Task 6: `prowlarr.py` — Prowlarr search + torrent fetch

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/prowlarr.py`
- Test: `modules/nixos/media/mediahub/tests/test_prowlarr.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_prowlarr.py
import httpx
import respx
from mediahub.prowlarr import ProwlarrClient, Release


@respx.mock
def test_search_parses_releases():
    payload = [{
        "title": "Some.Movie.2024.1080p.WEB-DL-GRP",
        "size": 12345, "seeders": 42, "indexer": "M-Team",
        "categories": [{"id": 2000, "name": "Movies"}],
        "downloadUrl": "http://pl/dl?id=1", "guid": "g1",
        "publishDate": "2024-01-01T00:00:00Z", "infoUrl": "http://pl/info/1",
    }]
    respx.get("http://pl/api/v1/search").mock(
        return_value=httpx.Response(200, json=payload)
    )
    c = ProwlarrClient("http://pl", "KEY")
    rels = c.search("some movie")
    assert len(rels) == 1
    r = rels[0]
    assert isinstance(r, Release)
    assert r.seeders == 42
    assert r.categories == [2000]
    assert r.download_url == "http://pl/dl?id=1"


@respx.mock
def test_fetch_torrent_returns_bytes():
    respx.get("http://pl/dl").mock(return_value=httpx.Response(200, content=b"d8:announce"))
    c = ProwlarrClient("http://pl", "KEY")
    assert c.fetch_torrent("http://pl/dl") == b"d8:announce"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_prowlarr.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.prowlarr`.

- [ ] **Step 3: Write `prowlarr.py`**

```python
# mediahub/prowlarr.py
from __future__ import annotations
from dataclasses import dataclass

import httpx


@dataclass
class Release:
    title: str
    size: int
    seeders: int
    indexer: str
    categories: list[int]
    download_url: str
    guid: str
    publish_date: str | None
    info_url: str | None


def _cat_ids(cats) -> list[int]:
    out = []
    for c in cats or []:
        cid = c.get("id") if isinstance(c, dict) else c
        if cid is not None:
            out.append(int(cid))
    return out


class ProwlarrClient:
    def __init__(self, base_url: str, api_key: str, client: httpx.Client | None = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.client = client or httpx.Client(timeout=30)

    def _headers(self):
        return {"X-Api-Key": self.api_key}

    def search(self, query, indexer_ids=None, categories=None) -> list[Release]:
        params: dict = {"query": query}
        if indexer_ids:
            params["indexerIds"] = indexer_ids
        if categories:
            params["categories"] = categories
        r = self.client.get(
            f"{self.base_url}/api/v1/search", params=params, headers=self._headers()
        )
        r.raise_for_status()
        return [
            Release(
                title=x.get("title", ""),
                size=int(x.get("size", 0) or 0),
                seeders=int(x.get("seeders", 0) or 0),
                indexer=x.get("indexer", ""),
                categories=_cat_ids(x.get("categories")),
                download_url=x.get("downloadUrl", ""),
                guid=x.get("guid", ""),
                publish_date=x.get("publishDate"),
                info_url=x.get("infoUrl"),
            )
            for x in r.json()
        ]

    def fetch_torrent(self, download_url: str) -> bytes:
        r = self.client.get(download_url, headers=self._headers())
        r.raise_for_status()
        return r.content
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_prowlarr.py -v`
Expected: PASS (2 passed).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/prowlarr.py modules/nixos/media/mediahub/tests/test_prowlarr.py
git commit -m "feat(mediahub): add prowlarr search client"
```

---

## Task 7: `transmission.py` — Transmission RPC client

Transmission's RPC returns 409 with a session-id header on the first call; the client retries once with it.

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/transmission.py`
- Test: `modules/nixos/media/mediahub/tests/test_transmission.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_transmission.py
import httpx
import respx
from mediahub.transmission import TransmissionClient


@respx.mock
def test_add_torrent_negotiates_session_and_returns_hash():
    calls = {"n": 0}

    def responder(request):
        calls["n"] += 1
        if calls["n"] == 1:
            return httpx.Response(409, headers={"X-Transmission-Session-Id": "SID"})
        assert request.headers["X-Transmission-Session-Id"] == "SID"
        return httpx.Response(200, json={
            "result": "success",
            "arguments": {"torrent-added": {"hashString": "abc"}},
        })

    respx.post("http://tr/rpc").mock(side_effect=responder)
    c = TransmissionClient("http://tr/rpc")
    h = c.add_torrent(b"torrentbytes", "/tank/media/downloads")
    assert h == "abc"
    assert calls["n"] == 2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_transmission.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.transmission`.

- [ ] **Step 3: Write `transmission.py`**

```python
# mediahub/transmission.py
from __future__ import annotations
import base64

import httpx


class TransmissionClient:
    def __init__(self, rpc_url: str, client: httpx.Client | None = None):
        self.rpc_url = rpc_url
        self.client = client or httpx.Client(timeout=30)
        self._sid = ""

    def _rpc(self, method: str, arguments: dict) -> dict:
        for _ in range(2):
            r = self.client.post(
                self.rpc_url,
                json={"method": method, "arguments": arguments},
                headers={"X-Transmission-Session-Id": self._sid},
            )
            if r.status_code == 409:
                self._sid = r.headers.get("X-Transmission-Session-Id", "")
                continue
            r.raise_for_status()
            return r.json()
        raise RuntimeError("transmission session negotiation failed")

    def add_torrent(self, torrent_bytes: bytes, download_dir: str) -> str:
        res = self._rpc("torrent-add", {
            "metainfo": base64.b64encode(torrent_bytes).decode(),
            "download-dir": download_dir,
        })
        args = res.get("arguments", {})
        t = args.get("torrent-added") or args.get("torrent-duplicate")
        if not t:
            raise RuntimeError(f"torrent-add failed: {res}")
        return t["hashString"]

    def get_torrent(self, hash: str) -> dict | None:
        res = self._rpc("torrent-get", {
            "ids": [hash],
            "fields": ["hashString", "downloadDir", "name", "files"],
        })
        torrents = res.get("arguments", {}).get("torrents", [])
        return torrents[0] if torrents else None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_transmission.py -v`
Expected: PASS (1 passed).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/transmission.py modules/nixos/media/mediahub/tests/test_transmission.py
git commit -m "feat(mediahub): add transmission rpc client"
```

---

## Task 8: `filer.py` — completion filer → Claude Code

The agent (Claude Code) does the actual `ln`. The filer builds the prompt, runs the agent
(injected for testing), parses the `RESULT:` line, and enqueues review on any failure.

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/filer.py`
- Test: `modules/nixos/media/mediahub/tests/test_filer.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_filer.py
from mediahub.filer import file_torrent, build_prompt
from mediahub.store import ReviewStore


def test_linked_result_no_review_row(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    agent = lambda prompt, cwd, env: "did work\nRESULT: linked 3\n"
    status = file_torrent("/dl/Foo", "Foo", "h1", "/tank/media", store, agent=agent)
    assert status == "linked"
    assert store.list_pending() == []


def test_review_result_creates_row_with_suggestion(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    out = "KIND: tv\nDEST: /tank/media/tv/Foo\nRESULT: review unknown season\n"
    agent = lambda prompt, cwd, env: out
    status = file_torrent("/dl/Foo", "Foo", "h2", "/tank/media", store, agent=agent)
    assert status == "review"
    p = store.list_pending()
    assert len(p) == 1
    assert p[0].suggested_kind == "tv"
    assert p[0].suggested_dest == "/tank/media/tv/Foo"
    assert "unknown season" in p[0].reason


def test_agent_error_enqueues_review(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    def boom(prompt, cwd, env):
        raise RuntimeError("claude exited 1")
    status = file_torrent("/dl/Foo", "Foo", "h3", "/tank/media", store, agent=boom)
    assert status == "review"
    assert "claude exited 1" in store.list_pending()[0].reason


def test_no_result_line_enqueues_review(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    agent = lambda prompt, cwd, env: "rambled but no verdict"
    status = file_torrent("/dl/Foo", "Foo", "h4", "/tank/media", store, agent=agent)
    assert status == "review"


def test_prompt_mentions_hardlink_only(tmp_path):
    p = build_prompt("/dl/Foo", "/tank/media")
    assert "/dl/Foo" in p and "/tank/media" in p
    assert "ln" in p and "never" in p.lower()


def test_dry_run_prompt_says_do_not_execute():
    p = build_prompt("/dl/Foo", "/tank/media", dry_run=True)
    assert "do not execute" in p.lower()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_filer.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.filer`.

- [ ] **Step 3: Write `filer.py`**

```python
# mediahub/filer.py
from __future__ import annotations
import os
import re
import subprocess

ALLOWED_TOOLS = "Read Bash(ls:*) Bash(stat:*) Bash(mkdir:*) Bash(ln:*)"
ALLOWED_TOOLS_DRY = "Read Bash(ls:*) Bash(stat:*)"  # no mkdir/ln — cannot change the fs
_RESULT = re.compile(r"^RESULT:\s*(linked|review)\b(.*)$", re.MULTILINE)
_KIND = re.compile(r"^KIND:\s*(.+)$", re.MULTILINE)
_DEST = re.compile(r"^DEST:\s*(.+)$", re.MULTILINE)


def build_prompt(torrent_dir: str, media_root: str, dry_run: bool = False) -> str:
    if dry_run:
        action = (
            "For each media (video/audio) file, PRINT the exact `ln` command you WOULD run to "
            "hardlink it into the correct place, one per line. DO NOT execute anything — do not "
            "create dirs, do not link."
        )
    else:
        action = (
            "Hardlink each media (video/audio) file into the correct place with `ln` (the plain "
            "command — NEVER `ln -s`, NEVER move or delete the source). Use `mkdir -p` for dirs."
        )
    return f"""You are filing a finished torrent into a Jellyfin media library using HARDLINKS only.

Source directory: {torrent_dir}
Library root: {media_root}
Category subfolders: movies, tv, anime, xxx, music.
Naming:
- movies/<Title> (<Year>)/<file>
- tv/<Title>/Season <NN>/<file>
- anime/<Title>/<file>
- xxx/<CODE>/<file>          (CODE = the JAV code, e.g. JUX-455)
- music/<Artist>/<Album>/<file>

Rules:
- Inspect the files with ls/stat first.
- {action}
- Skip samples, .nfo, .rar, and other non-media files.
- If confident, end with EXACTLY one line: `RESULT: linked <count>`
- If you cannot confidently decide (ambiguous, mixed pack, unknown season), do NOT link.
  Output `KIND: <kind>` and `DEST: <path>` with your best guess if you have one, then
  end with EXACTLY one line: `RESULT: review <short reason>`
"""


def run_agent(prompt: str, cwd: str, env: dict) -> str:
    claude = env.get("CLAUDE_BIN", "claude")
    tools = ALLOWED_TOOLS_DRY if env.get("DRY_RUN") else ALLOWED_TOOLS
    proc = subprocess.run(
        [claude, "-p", prompt, "--allowedTools", tools],
        cwd=cwd, env=env, capture_output=True, text=True, timeout=600,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"claude exited {proc.returncode}: {proc.stderr[:500]}")
    return proc.stdout


def file_torrent(torrent_dir, name, hash, media_root, store, agent=run_agent, env=None) -> str:
    env = env if env is not None else os.environ.copy()
    prompt = build_prompt(torrent_dir, media_root, dry_run=bool(env.get("DRY_RUN")))
    try:
        out = agent(prompt, cwd=torrent_dir, env=env)
    except Exception as e:  # any agent failure -> review, never crash
        store.add(hash, name, str(torrent_dir), None, None, f"agent error: {e}")
        return "review"

    m = _RESULT.search(out or "")
    if not m:
        store.add(hash, name, str(torrent_dir), None, None, "no RESULT line from agent")
        return "review"
    if m.group(1) == "review":
        km, dm = _KIND.search(out), _DEST.search(out)
        store.add(
            hash, name, str(torrent_dir),
            km.group(1).strip() if km else None,
            dm.group(1).strip() if dm else None,
            (m.group(2).strip() or "agent requested review"),
        )
        return "review"
    return "linked"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_filer.py -v`
Expected: PASS (6 passed).

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/filer.py modules/nixos/media/mediahub/tests/test_filer.py
git commit -m "feat(mediahub): add completion filer invoking claude code"
```

---

## Task 9: `web.py` + templates — FastAPI app

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/web.py`
- Create: `modules/nixos/media/mediahub/mediahub/templates/search.html`
- Create: `modules/nixos/media/mediahub/mediahub/templates/results.html`
- Create: `modules/nixos/media/mediahub/mediahub/templates/review.html`
- Test: `modules/nixos/media/mediahub/tests/test_web.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_web.py
from types import SimpleNamespace
from fastapi.testclient import TestClient
from mediahub.web import create_app
from mediahub.prowlarr import Release
from mediahub.store import ReviewStore


def _release(title, seeders=10):
    return Release(title=title, size=1, seeders=seeders, indexer="M-Team",
                   categories=[2000], download_url="http://pl/dl?id=1", guid="g",
                   publish_date=None, info_url=None)


class FakeProwlarr:
    def __init__(self, releases): self._r = releases; self.fetched = None
    def search(self, query, indexer_ids=None, categories=None): return self._r
    def fetch_torrent(self, url): self.fetched = url; return b"torrentbytes"


class FakeTransmission:
    def __init__(self): self.added = None
    def add_torrent(self, data, download_dir): self.added = (data, download_dir); return "hash9"


def _client(tmp_path, releases):
    cfg = SimpleNamespace(downloads_dir="/dl", media_root="/tank/media")
    pl = FakeProwlarr(releases)
    tr = FakeTransmission()
    store = ReviewStore(tmp_path / "r.db")
    app = create_app(cfg, pl, tr, store)
    return TestClient(app), pl, tr, store


def test_search_returns_rows_and_filters_by_resolution(tmp_path):
    releases = [
        _release("A.Movie.2024.2160p.WEB-DL-X"),
        _release("B.Movie.2024.1080p.WEB-DL-Y"),
    ]
    client, *_ = _client(tmp_path, releases)
    r = client.get("/api/search", params={"q": "movie"})
    assert r.status_code == 200
    assert "A.Movie" in r.text and "B.Movie" in r.text
    r2 = client.get("/api/search", params={"q": "movie", "resolution": "2160p"})
    assert "A.Movie" in r2.text and "B.Movie" not in r2.text


def test_grab_fetches_and_adds(tmp_path):
    client, pl, tr, _ = _client(tmp_path, [])
    r = client.post("/api/grab", data={"downloadUrl": "http://pl/dl?id=1", "title": "A"})
    assert r.status_code == 200
    assert pl.fetched == "http://pl/dl?id=1"
    assert tr.added == (b"torrentbytes", "/dl")


def test_review_lists_pending(tmp_path):
    client, _, _, store = _client(tmp_path, [])
    store.add("h", "Pending.Thing", "/dl/Pending.Thing", "tv", "/tank/media/tv/X", "why")
    r = client.get("/review")
    assert r.status_code == 200
    assert "Pending.Thing" in r.text
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_web.py -v`
Expected: FAIL — `ModuleNotFoundError: mediahub.web`.

- [ ] **Step 3: Write the templates**

`mediahub/templates/search.html`:
```html
<!doctype html>
<html><head><title>mediahub</title>
<script src="https://unpkg.com/htmx.org@1.9.12"></script></head>
<body>
<h1>mediahub</h1>
<form hx-get="/api/search" hx-target="#results">
  <input name="q" placeholder="search..." autofocus>
  <input name="resolution" placeholder="resolution (e.g. 1080p)">
  <input name="source" placeholder="source (e.g. WEB-DL)">
  <input name="group" placeholder="group">
  <input name="min_seeders" placeholder="min seeders" type="number">
  <button>Search</button>
</form>
<p><a href="/review">Review queue</a></p>
<div id="results"></div>
</body></html>
```

`mediahub/templates/results.html`:
```html
<table border="1">
<tr><th>Title</th><th>Site</th><th>Res</th><th>Source</th><th>Codec</th>
    <th>Group</th><th>Seed</th><th>Size(GB)</th><th></th></tr>
{% for row in rows %}
<tr>
  <td>{{ row.r.title }}</td><td>{{ row.r.indexer }}</td>
  <td>{{ row.f.resolution or "" }}</td><td>{{ row.f.source or "" }}</td>
  <td>{{ row.f.codec or "" }}</td><td>{{ row.f.group or "" }}</td>
  <td>{{ row.r.seeders }}</td><td>{{ "%.1f"|format(row.r.size / 1073741824) }}</td>
  <td><form hx-post="/api/grab" hx-swap="none">
    <input type="hidden" name="downloadUrl" value="{{ row.r.download_url }}">
    <input type="hidden" name="title" value="{{ row.r.title }}">
    <button>Grab</button></form></td>
</tr>
{% endfor %}
</table>
<p>{{ rows|length }} results</p>
```

`mediahub/templates/review.html`:
```html
<!doctype html><html><head><title>review</title></head><body>
<h1>Review queue</h1><p><a href="/">back to search</a></p>
{% for item in items %}
<div style="border:1px solid #ccc;margin:6px;padding:6px">
  <b>{{ item.name }}</b> — {{ item.reason }}<br>
  src: {{ item.src_dir }}<br>
  <form method="post" action="/api/place">
    <input type="hidden" name="id" value="{{ item.id }}">
    <input name="dest" size="60" value="{{ item.suggested_dest or '' }}">
    <button>Place (hardlink)</button>
  </form>
</div>
{% else %}<p>Nothing pending.</p>{% endfor %}
</body></html>
```

- [ ] **Step 4: Write `web.py`**

```python
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
        return templates.TemplateResponse("search.html", {"request": request})

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
        return templates.TemplateResponse("results.html", {"request": request, "rows": rows})

    @app.post("/api/grab")
    def grab(downloadUrl: str = Form(...), title: str = Form(...)):
        data = prowlarr.fetch_torrent(downloadUrl)
        h = transmission.add_torrent(data, config.downloads_dir)
        return JSONResponse({"ok": True, "hash": h, "title": title})

    @app.get("/review", response_class=HTMLResponse)
    def review(request: Request):
        return templates.TemplateResponse(
            "review.html", {"request": request, "items": store.list_pending()}
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `uv run pytest tests/test_web.py -v`
Expected: PASS (3 passed). (`python-multipart` must be installed for `Form` — it's in the deps.)

- [ ] **Step 6: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/web.py modules/nixos/media/mediahub/mediahub/templates modules/nixos/media/mediahub/tests/test_web.py
git commit -m "feat(mediahub): add fastapi search/grab/review web app"
```

---

## Task 10: `cli.py` — console entry points

**Files:**
- Create: `modules/nixos/media/mediahub/mediahub/cli.py`

- [ ] **Step 1: Write `cli.py`**

```python
# mediahub/cli.py
from __future__ import annotations
import os

from .config import Config
from .store import ReviewStore
from .prowlarr import ProwlarrClient
from .transmission import TransmissionClient


def web() -> None:
    """Entry point: `mediahub-web`. Serves the FastAPI app with uvicorn."""
    import uvicorn
    from .web import create_app

    cfg = Config.from_env()
    app = create_app(
        cfg,
        ProwlarrClient(cfg.prowlarr_url, cfg.prowlarr_api_key),
        TransmissionClient(cfg.transmission_rpc_url),
        ReviewStore(cfg.db_path),
    )
    uvicorn.run(app, host=os.environ.get("MEDIAHUB_HOST", "127.0.0.1"),
                port=int(os.environ.get("MEDIAHUB_PORT", "8083")))


def file_done() -> None:
    """Entry point: `mediahub-file`. Invoked by Transmission's script-torrent-done
    (as the transmission user) with TR_TORRENT_* env vars set."""
    from .filer import file_torrent

    cfg = Config.from_env()
    torrent_dir = os.path.join(
        os.environ["TR_TORRENT_DIR"], os.environ["TR_TORRENT_NAME"]
    )
    name = os.environ["TR_TORRENT_NAME"]
    thash = os.environ.get("TR_TORRENT_HASH", "")
    status = file_torrent(torrent_dir, name, thash, cfg.media_root, ReviewStore(cfg.db_path))
    print(f"mediahub-file: {name} -> {status}")
```

- [ ] **Step 2: Verify entry points resolve**

Run (from `modules/nixos/media/mediahub`): `uv run mediahub-web --help 2>/dev/null || uv run python -c "from mediahub.cli import web, file_done; print('ok')"`
Expected: prints `ok` (imports resolve; do not start the server here).

- [ ] **Step 3: Run the full test suite**

Run: `uv run pytest -q`
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/media/mediahub/mediahub/cli.py
git commit -m "feat(mediahub): add web + filer console entry points"
```

---

# Phase 2 — NixOS deployment

> These tasks change system config. Build with `nix eval`/`nixos-rebuild build` (no sudo).
> The final activation (`nixos-rebuild switch`) and the secret-file creation are **manual
> steps the user runs via the `!` prefix** (sudo needs their password).

## Task 11: `prowlarr.nix` — headless Prowlarr module

**Files:**
- Create: `modules/nixos/media/prowlarr.nix`

- [ ] **Step 1: Write the module**

```nix
# modules/nixos/media/prowlarr.nix
# Headless Prowlarr — the search engine aggregating HDSky / M-Team / OpenCD.
# Used ONLY as a search API + authenticated .torrent proxy by mediahub. The three
# indexers and their credentials are added once through the web UI (:9696, LAN)
# and live in Prowlarr's own state DB — not the Nix store. Prowlarr generates its
# API key on first run; copy it into /var/lib/mediahub-secrets/env (see mediahub.nix).
_: {
  services.prowlarr = {
    enable = true;
    openFirewall = false; # LAN rule is in firewall.nix
  };
}
```

- [ ] **Step 2: Syntax-check the module**

Run: `nix-instantiate --parse modules/nixos/media/prowlarr.nix >/dev/null && echo OK`
Expected: prints `OK`. (Full evaluation happens once it is imported and built in Task 14.)

- [ ] **Step 3: Format + commit**

```bash
nix fmt -- modules/nixos/media/prowlarr.nix
git add modules/nixos/media/prowlarr.nix
git commit -m "feat(media): add headless prowlarr module"
```

---

## Task 12: `mediahub.nix` — package the app + web service

**Files:**
- Create: `modules/nixos/media/mediahub.nix`

- [ ] **Step 1: Write the module**

Notes: `mediahub` runs as its own user in the `media` group. Prowlarr's API key comes
from a root-only env file (created manually, Task 15). The filer binary
(`mediahub-file`) is installed system-wide so the Transmission hook (Task 13) can exec it.

```nix
# modules/nixos/media/mediahub.nix
# mediahub — faceted PT search/grab web app (mediahub-web) + the completion filer
# binary (mediahub-file, run by Transmission's hook, see nixmachine/default.nix).
# The app is built from in-repo source with buildPythonApplication.
{
  config,
  pkgs,
  lib,
  ...
}: let
  py = pkgs.python3Packages;
  mediahub = py.buildPythonApplication {
    pname = "mediahub";
    version = "0.1.0";
    pyproject = true;
    src = ./mediahub;
    build-system = [py.hatchling];
    dependencies = with py; [
      fastapi
      uvicorn
      httpx
      guessit
      jinja2
      python-multipart
    ];
    # Tests run in the Nix dev loop via uv; skip in the package build.
    doCheck = false;
  };
in {
  # Expose the built app + the filer binary system-wide (for the Transmission hook).
  environment.systemPackages = [mediahub];

  users.groups.mediahub = {};
  users.users.mediahub = {
    isSystemUser = true;
    group = "mediahub";
    extraGroups = ["media"]; # read downloads + hardlink into the library
    description = "mediahub web service identity";
  };

  systemd.tmpfiles.rules = [
    # Review DB dir — group `media` so the transmission-run filer can write it too.
    "d /var/lib/mediahub         2775 mediahub media -"
    "d /var/lib/mediahub-secrets 0700 root     root  -"
  ];

  systemd.services.mediahub-web = {
    description = "mediahub search/grab/review web app";
    after = ["network.target" "prowlarr.service"];
    wantedBy = ["multi-user.target"];
    environment = {
      MEDIAHUB_HOST = "127.0.0.1";
      MEDIAHUB_PORT = "8083";
      MEDIA_ROOT = "/tank/media";
      DOWNLOADS_DIR = "/tank/media/downloads";
      MEDIAHUB_DB = "/var/lib/mediahub/review.db";
      PROWLARR_URL = "http://127.0.0.1:9696";
      TRANSMISSION_RPC_URL = "http://127.0.0.1:9091/transmission/rpc";
    };
    serviceConfig = {
      ExecStart = "${mediahub}/bin/mediahub-web";
      User = "mediahub";
      Group = "media";
      UMask = "0002";
      # PROWLARR_API_KEY — created manually (Task 15).
      EnvironmentFile = "/var/lib/mediahub-secrets/env";
      ReadWritePaths = ["/tank/media" "/var/lib/mediahub"];
      Restart = "on-failure";
    };
  };
}
```

- [ ] **Step 2: Format**

Run: `nix fmt -- modules/nixos/media/mediahub.nix`

- [ ] **Step 3: Commit (build is verified in Task 14 once imported)**

```bash
git add modules/nixos/media/mediahub.nix
git commit -m "feat(media): package mediahub app + web service"
```

---

## Task 13: Wire the Transmission completion hook (in `mediahub.nix`)

The hook must reference the built `mediahub` binary and `claude-code` by store path, which
are only in scope inside `mediahub.nix`. NixOS merges module config across files, so we add
the Transmission settings + sandbox overrides here (not in `hosts/`), keeping the wiring next
to the derivation. `hosts/nixos/nixmachine/default.nix` is left untouched.

**Files:**
- Modify: `modules/nixos/media/mediahub.nix`

- [ ] **Step 1: Verify `pkgs.claude-code` exists on the pinned channel**

Run: `nix eval --raw .#nixosConfigurations.nixmachine.pkgs.claude-code.name 2>&1 | tail -1`
Expected: a name like `claude-code-<version>`. If it errors ("attribute missing"), STOP and
switch to a wrapped/pinned install of the CLI; note it in review before proceeding.

- [ ] **Step 2: Add the hook wrapper to the `let` block of `mediahub.nix`**

After the `mediahub` derivation (still inside `let … in`), add:

```nix
  # The Transmission done-hook: runs as the `transmission` user, sets the env the
  # filer needs, and execs the mediahub-file binary by store path.
  doneHook = pkgs.writeShellScript "mediahub-done-hook" ''
    export MEDIA_ROOT=/tank/media
    export MEDIAHUB_DB=/var/lib/mediahub/review.db
    export CLAUDE_BIN=${pkgs.claude-code}/bin/claude
    export HOME=/var/lib/transmission/.mediahub-home
    exec ${mediahub}/bin/mediahub-file
  '';
```

- [ ] **Step 3: Add the settings + sandbox widening to the module body**

In the attrset after `in {`, add (these merge with the Transmission config in
`hosts/nixos/nixmachine/default.nix`):

```nix
  # Fire the filer on completion.
  services.transmission.settings = {
    script-torrent-done-enabled = true;
    script-torrent-done-filename = "${doneHook}";
  };

  # The hook runs inside transmission.service's sandbox — widen it so the filer can
  # hardlink into the library, write the review DB, run claude, and read its key.
  systemd.services.transmission.serviceConfig = {
    EnvironmentFile = "/var/lib/mediahub-secrets/transmission-env"; # ANTHROPIC_API_KEY
    ReadWritePaths = ["/tank/media" "/var/lib/mediahub"];
  };
```

Then extend the existing `systemd.tmpfiles.rules` list in this module (from Task 12) with
Claude's home dir:

```nix
    "d /var/lib/transmission/.mediahub-home 0750 transmission transmission -"
```

- [ ] **Step 4: Format + commit (full build verified in Task 14)**

```bash
nix fmt -- modules/nixos/media/mediahub.nix
git add modules/nixos/media/mediahub.nix
git commit -m "feat(media): fire mediahub filer from transmission done-hook"
```

---

## Task 14: Firewall + module imports, then build the whole config

**Files:**
- Modify: `modules/nixos/media/firewall.nix`
- Modify: `modules/nixos/media/default.nix`

- [ ] **Step 1: Open the LAN ports**

Edit `modules/nixos/media/firewall.nix` — replace the single-port rule:

```nix
# Ports: jellyfin 8096 · mediahub 8083 · prowlarr 9696.
_: {
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport { 8096, 8083, 9696 } accept
  '';
}
```

- [ ] **Step 2: Import the new modules**

Edit `modules/nixos/media/default.nix` imports list to add `./prowlarr.nix` and `./mediahub.nix`:

```nix
  imports = [
    ./storage.nix
    ./jellyfin.nix
    ./metatube.nix
    ./prowlarr.nix
    ./mediahub.nix
    ./firewall.nix
  ];
```

- [ ] **Step 3: Format + build the whole system**

Run: `nix fmt`
Run: `nixos-rebuild build --flake .#nixmachine`
Expected: builds successfully (produces `./result`). Fix any eval/build errors before continuing. This is the real check that Tasks 11–13 evaluate together.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/media/firewall.nix modules/nixos/media/default.nix
git commit -m "feat(media): import prowlarr + mediahub, open LAN ports"
```

---

## Task 15: Secrets, activation, and first-run runbook (manual)

These steps require sudo / the running services; the user runs them via the `!` prefix.
This task documents them; nothing to commit unless noted.

- [ ] **Step 1: Activate the new config**

`! sudo nixos-rebuild switch --flake .#nixmachine`
Expected: `prowlarr.service` and `mediahub-web.service` appear. `mediahub-web` will fail to
start until the secret file exists (next step) — that's expected.

- [ ] **Step 2: Configure Prowlarr + capture its API key**

1. Browse to `http://nixmachine:9696`, add the three indexers (HDSky, M-Team, OpenCD) with
   credentials, and confirm a test search returns results.
2. Settings → General → API Key: copy it.

- [ ] **Step 3: Create the secret env files (root-only)**

`mediahub-web` needs the Prowlarr key; the Transmission-run filer needs the Anthropic key.

```
! sudo install -d -m 0700 /var/lib/mediahub-secrets
! printf 'PROWLARR_API_KEY=%s\n' 'PASTE_PROWLARR_KEY' | sudo tee /var/lib/mediahub-secrets/env >/dev/null
! printf 'ANTHROPIC_API_KEY=%s\n' 'PASTE_ANTHROPIC_KEY' | sudo tee /var/lib/mediahub-secrets/transmission-env >/dev/null
! sudo chmod 0640 /var/lib/mediahub-secrets/transmission-env
! sudo chgrp transmission /var/lib/mediahub-secrets/transmission-env
! sudo systemctl restart mediahub-web
```
(The Anthropic key can be the same value already in `/var/lib/litellm-secrets/env`.)

- [ ] **Step 4: Smoke-test search + grab**

- Browse `http://nixmachine:8083`, search a title, confirm the faceted table renders and
  the resolution/source/group filters narrow results.
- Click **Grab** on a small release; confirm it appears in Transmission
  (`transmission-remote 127.0.0.1:9091 -l`).

- [ ] **Step 5: Dry-run the filer once, then a live run**

Before trusting the auto-hardlink, run the filer manually as `transmission` against a finished
torrent with `DRY_RUN=1` — the agent is allow-listed to read/`ls`/`stat` only (no `mkdir`/`ln`)
and prints the `ln` commands it *would* run:

```
! sudo -u transmission env \
    TR_TORRENT_DIR=/tank/media/downloads TR_TORRENT_NAME='<finished-name>' TR_TORRENT_HASH=dryrun \
    MEDIA_ROOT=/tank/media MEDIAHUB_DB=/var/lib/mediahub/review.db \
    HOME=/var/lib/transmission/.mediahub-home DRY_RUN=1 \
    CLAUDE_BIN="$(nix eval --raw .#nixosConfigurations.nixmachine.pkgs.claude-code)/bin/claude" \
    /run/current-system/sw/bin/mediahub-file
```
Review the printed `ln` commands. If they look right, either re-run the same command **without**
`DRY_RUN=1` (and with a real `TR_TORRENT_HASH`) to perform the links, or just let the next real
completed download trigger the hook. Confirm a link landed with
`find /tank/media/<kind> -samefile '/tank/media/downloads/<finished-name>/<file>'` (shows 2 paths).

- [ ] **Step 6: Verify the review queue**

Browse `http://nixmachine:8083/review`; place any pending item and confirm the hardlink lands.

---

## Self-review notes (for the plan author / executor)

- **Spec coverage:** search + facets (Task 3, 9), grab→Transmission (7, 9), completion hook →
  Claude Code filing (8, 13), review queue (5, 9, 15), hardlink-only + seed safety (4, 8, 13),
  `--allowedTools` guard + dry-run (8, 15), Prowlarr engine (11), LAN firewall + secrets out of
  store (14, 15), NixOS declarative (11–14).
- **Known risk to verify early (Task 13 Step 1):** `pkgs.claude-code` availability on the
  pinned channel. If absent, adjust before Task 14's build.
- **Sandbox:** Transmission's hardening means the filer only works after the `ReadWritePaths`
  + `EnvironmentFile` additions and the `doneHook` env exports in Task 13; the Task 15 dry-run
  is the real proof.
- **`hosts/nixos/nixmachine/default.nix` is not modified** — all Transmission-hook wiring lives
  in `mediahub.nix` (module config merges), so the existing Transmission block stays as-is.
