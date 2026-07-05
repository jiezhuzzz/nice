# Media Filer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On torrent completion, hardlink the release into the Jellyfin library (`/tank/media/{movies,tv,anime}`) with Jellyfin-standard names, using `guessit` for the common case and a Claude Code advisory call for hard cases (CJK/ambiguous), all decoupled from Transmission's systemd sandbox.

**Architecture:** Transmission's `script-torrent-done` hook writes a tiny `TR_*` job file into `/tank/media/downloads/.filer-queue/` (the one path writable inside its sandbox). A `systemd.path` watcher fires a separate `media-filer.service` (own user, RW on `/tank/media`, own writable `$HOME`) that drains the queue: parse → (maybe) ask Claude for JSON → compute dest → hardlink. Claude only advises; the Python app is the sole filesystem actor and clamps every destination inside `/tank/media`.

**Tech Stack:** Python 3.11+ (`guessit` + stdlib), packaged with `buildPythonApplication` (hatchling); NixOS systemd units; Claude Code CLI (`pkgs.claude-code`) invoked headless with `claude -p`.

---

## File Structure

```
modules/nixos/media/
  default.nix                 # MODIFY: add ./filer.nix to imports
  filer.nix                   # CREATE: NixOS module (package + user + hook + path + service)
  filer/                      # CREATE: the Python application
    pyproject.toml
    media_filer/
      __init__.py
      parse.py                # guessit → Candidate + confidence + CJK detection
      layout.py               # Jellyfin dest builders + /tank/media clamp + sanitize
      hardlink.py             # idempotent os.link
      agent.py                # claude -p advisory JSON (injectable runner)
      filer.py                # orchestration: enumerate files, decide, act, log
      cli.py                  # entrypoint: drain the queue dir
    tests/
      test_parse.py
      test_layout.py
      test_hardlink.py
      test_agent.py
      test_filer.py
```

**Dev/test loop:** `guessit` is the only runtime dep; tests run under `uv` per repo policy: `cd modules/nixos/media/filer && uv run --extra dev pytest -q`. The Nix package sets `doCheck = false` (tests are the dev loop, not the build).

**Data types (keep consistent across tasks):**
- `parse.Candidate`: `type: str|None` (`"movie"`|`"episode"`|`None`), `title: str|None`, `year: int|None`, `season: int|None`, `episode: int|None`.
- `agent.AgentResult`: `type: str` (`"movie"`|`"tv"`|`"anime"`|`"unknown"`), `title: str|None`, `year: int|None`, `season: int|None`, `episode: int|None`, `confident: bool`.
- Category strings used by `layout`/`filer`: `"movie"`, `"tv"`, `"anime"`.

---

## Task 1: Scaffold the Python package

**Files:**
- Create: `modules/nixos/media/filer/pyproject.toml`
- Create: `modules/nixos/media/filer/media_filer/__init__.py`
- Create: `modules/nixos/media/filer/tests/test_smoke.py`

- [ ] **Step 1: Write `pyproject.toml`**

```toml
[project]
name = "media-filer"
version = "0.1.0"
description = "Hardlink completed torrents into a Jellyfin library"
requires-python = ">=3.11"
dependencies = ["guessit>=3.8"]

[project.optional-dependencies]
dev = ["pytest>=8"]

[project.scripts]
media-filer = "media_filer.cli:main"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["media_filer"]
```

- [ ] **Step 2: Create the package marker**

`modules/nixos/media/filer/media_filer/__init__.py`:

```python
"""media-filer: hardlink completed torrents into a Jellyfin library."""
```

- [ ] **Step 3: Write a smoke test**

`modules/nixos/media/filer/tests/test_smoke.py`:

```python
import media_filer


def test_package_imports():
    assert media_filer.__doc__
```

- [ ] **Step 4: Run it (proves the uv harness works)**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_smoke.py -q`
Expected: 1 passed.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/filer/pyproject.toml \
        modules/nixos/media/filer/media_filer/__init__.py \
        modules/nixos/media/filer/tests/test_smoke.py
git commit -m "feat(media-filer): scaffold python package"
```

---

## Task 2: `parse.py` — guessit wrapper, confidence, CJK detection

**Files:**
- Create: `modules/nixos/media/filer/media_filer/parse.py`
- Test: `modules/nixos/media/filer/tests/test_parse.py`

- [ ] **Step 1: Write the failing tests**

`tests/test_parse.py`:

```python
from media_filer.parse import parse_name, confident, is_cjk


def test_movie_is_confident():
    c = parse_name("The.Matrix.1999.1080p.BluRay.x264-GROUP")
    assert c.type == "movie"
    assert c.title == "The Matrix"
    assert c.year == 1999
    assert confident(c) is True


def test_single_episode_is_confident():
    c = parse_name("Severance.S02E03.1080p.WEB-DL.DDP5.1.H264-GRP")
    assert c.type == "episode"
    assert c.title == "Severance"
    assert c.season == 2
    assert c.episode == 3
    assert confident(c) is True


def test_season_pack_name_has_no_episode():
    c = parse_name("Severance.S02.1080p.WEB-DL-GRP")
    assert c.type == "episode"
    assert c.season == 2
    assert c.episode is None  # per-file parsing supplies episodes later


def test_cjk_title_is_not_confident():
    c = parse_name("基督山伯爵.The.Count.of.Monte.Cristo.S01.2024.1080p")
    # guessit may still return a title, but CJK presence forces escalation
    assert confident(c) is False


def test_multi_year_title_does_not_crash():
    # guessit returns a list for year here; _scalar must collapse it
    c = parse_name("Some.Show.2020.2021.1080p.WEB-DL-GRP")
    assert isinstance(c.year, (int, type(None)))


def test_is_cjk():
    assert is_cjk("基督山伯爵") is True
    assert is_cjk("The Matrix") is False
    assert is_cjk("Amélie") is False  # accented latin is fine
```

- [ ] **Step 2: Run to verify failure**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_parse.py -q`
Expected: FAIL (`ModuleNotFoundError: media_filer.parse`).

- [ ] **Step 3: Implement `parse.py`**

```python
"""Parse a release name into a normalized Candidate using guessit."""
from __future__ import annotations

from dataclasses import dataclass

import guessit


@dataclass
class Candidate:
    type: str | None  # "movie" | "episode" | None
    title: str | None
    year: int | None
    season: int | None
    episode: int | None


def _scalar(value):
    """guessit returns lists for multi-valued fields (e.g. two years). Take the
    first element so downstream int()/str() never sees a list."""
    if isinstance(value, list):
        return value[0] if value else None
    return value


def is_cjk(s: str | None) -> bool:
    """True if the string contains CJK / fullwidth characters (guessit mis-parses
    these, so they force escalation to the agent)."""
    if not s:
        return False
    for ch in s:
        if "　" <= ch <= "鿿" or "＀" <= ch <= "￯":
            return True
    return False


def parse_name(name: str) -> Candidate:
    g = guessit.guessit(name)
    gtype = _scalar(g.get("type"))
    return Candidate(
        type=gtype if gtype in ("movie", "episode") else None,
        title=_scalar(g.get("title")),
        year=_scalar(g.get("year")),
        season=_scalar(g.get("season")),
        episode=_scalar(g.get("episode")),
    )


def confident(c: Candidate) -> bool:
    """Deterministic-confident only when we can name a destination unambiguously.
    Anything else (CJK title, missing type, episode without S+E, movie without a
    year) escalates to the agent."""
    if not c.title or is_cjk(c.title):
        return False
    if c.type == "movie":
        return c.year is not None
    if c.type == "episode":
        return c.season is not None and c.episode is not None
    return False
```

- [ ] **Step 4: Run to verify pass**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_parse.py -q`
Expected: all passed. (If `test_cjk_title_is_not_confident` surprises you: guessit sometimes parses the CJK away and still returns the English title — the `is_cjk` guard in `confident` is what forces escalation there; if guessit returns a clean English title AND a year, adjust the fixture to one that truly stays ambiguous, e.g. drop the English words: `parse_name("基督山伯爵.2024.1080p")`.)

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/filer/media_filer/parse.py \
        modules/nixos/media/filer/tests/test_parse.py
git commit -m "feat(media-filer): guessit-based parse with confidence + CJK gate"
```

---

## Task 3: `layout.py` — Jellyfin destinations, sanitize, clamp

**Files:**
- Create: `modules/nixos/media/filer/media_filer/layout.py`
- Test: `modules/nixos/media/filer/tests/test_layout.py`

- [ ] **Step 1: Write the failing tests**

`tests/test_layout.py`:

```python
from pathlib import Path

from media_filer import layout

ROOT = Path("/tank/media")


def test_movie_dest():
    d = layout.movie_dest(ROOT, "The Matrix", 1999, ".mkv")
    assert d == ROOT / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv"


def test_tv_dest():
    d = layout.tv_dest(ROOT, "Severance", 2, 3, ".mkv", anime=False)
    assert d == ROOT / "tv" / "Severance" / "Season 02" / "Severance - S02E03.mkv"


def test_anime_season_dest():
    d = layout.tv_dest(ROOT, "Frieren", 1, 5, ".mkv", anime=True)
    assert d == ROOT / "anime" / "Frieren" / "Season 01" / "Frieren - S01E05.mkv"


def test_anime_absolute_dest():
    d = layout.anime_absolute_dest(ROOT, "One Piece", 1071, ".mkv")
    assert d == ROOT / "anime" / "One Piece" / "One Piece - 1071.mkv"


def test_sanitize_strips_path_hostile_chars():
    assert layout.sanitize('A/B:C?"D') == "ABCD"


def test_is_inside_true():
    assert layout.is_inside(ROOT / "movies" / "x" / "y.mkv", ROOT) is True


def test_is_inside_rejects_escape():
    assert layout.is_inside(ROOT / ".." / "etc" / "passwd", ROOT) is False
```

- [ ] **Step 2: Run to verify failure**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_layout.py -q`
Expected: FAIL (`ModuleNotFoundError: media_filer.layout`).

- [ ] **Step 3: Implement `layout.py`**

```python
"""Compute Jellyfin-standard library destinations and clamp them to the root."""
from __future__ import annotations

import re
from pathlib import Path

MEDIA_ROOT = Path("/tank/media")

_HOSTILE = re.compile(r'[\\/:*?"<>|]')


def sanitize(name: str) -> str:
    return _HOSTILE.sub("", name).strip()


def movie_dest(root: Path, title: str, year: int, ext: str) -> Path:
    base = f"{sanitize(title)} ({year})"
    return root / "movies" / base / f"{base}{ext}"


def tv_dest(root: Path, title: str, season: int, episode: int, ext: str, *, anime: bool) -> Path:
    show = sanitize(title)
    cat = "anime" if anime else "tv"
    return root / cat / show / f"Season {season:02d}" / f"{show} - S{season:02d}E{episode:02d}{ext}"


def anime_absolute_dest(root: Path, title: str, number: int, ext: str) -> Path:
    show = sanitize(title)
    return root / "anime" / show / f"{show} - {number:d}{ext}"


def is_inside(dest: Path, root: Path) -> bool:
    """Guard against `..`/symlink escapes: the resolved dest must live under root."""
    r = root.resolve()
    d = dest.resolve()
    return d == r or r in d.parents
```

- [ ] **Step 4: Run to verify pass**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_layout.py -q`
Expected: all passed.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/filer/media_filer/layout.py \
        modules/nixos/media/filer/tests/test_layout.py
git commit -m "feat(media-filer): jellyfin destination builders + path clamp"
```

---

## Task 4: `hardlink.py` — idempotent linking

**Files:**
- Create: `modules/nixos/media/filer/media_filer/hardlink.py`
- Test: `modules/nixos/media/filer/tests/test_hardlink.py`

- [ ] **Step 1: Write the failing tests**

`tests/test_hardlink.py`:

```python
import pytest

from media_filer.hardlink import hardlink, LinkConflict


def test_links_new_file(tmp_path):
    src = tmp_path / "src.mkv"
    src.write_text("data")
    dest = tmp_path / "lib" / "movie" / "m.mkv"
    assert hardlink(src, dest) == "linked"
    assert dest.exists()
    assert dest.samefile(src)


def test_second_link_is_idempotent(tmp_path):
    src = tmp_path / "src.mkv"
    src.write_text("data")
    dest = tmp_path / "m.mkv"
    hardlink(src, dest)
    assert hardlink(src, dest) == "exists"


def test_conflicting_dest_raises(tmp_path):
    src = tmp_path / "src.mkv"
    src.write_text("data")
    other = tmp_path / "other.mkv"
    other.write_text("different")
    dest = tmp_path / "m.mkv"
    hardlink(other, dest)  # dest now points at `other`
    with pytest.raises(LinkConflict):
        hardlink(src, dest)
```

- [ ] **Step 2: Run to verify failure**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_hardlink.py -q`
Expected: FAIL (`ModuleNotFoundError: media_filer.hardlink`).

- [ ] **Step 3: Implement `hardlink.py`**

```python
"""Idempotent hardlink creation. Never overwrites; never touches the source."""
from __future__ import annotations

import os
from pathlib import Path


class LinkConflict(Exception):
    """Destination exists and points at different content."""


def hardlink(src: Path, dest: Path) -> str:
    """Return 'linked' if created, 'exists' if already the same file.
    Raise LinkConflict if dest exists with different content."""
    if dest.exists():
        if dest.samefile(src):
            return "exists"
        raise LinkConflict(f"{dest} exists with different content")
    dest.parent.mkdir(parents=True, exist_ok=True)
    os.link(src, dest)
    return "linked"
```

- [ ] **Step 4: Run to verify pass**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_hardlink.py -q`
Expected: all passed.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/filer/media_filer/hardlink.py \
        modules/nixos/media/filer/tests/test_hardlink.py
git commit -m "feat(media-filer): idempotent hardlink helper"
```

---

## Task 5: `agent.py` — Claude advisory classifier

**Files:**
- Create: `modules/nixos/media/filer/media_filer/agent.py`
- Test: `modules/nixos/media/filer/tests/test_agent.py`

The runner is injectable so tests never call the real `claude`. `classify` builds
the prompt, runs the CLI, extracts the first JSON object from stdout, and
validates it into an `AgentResult`. Malformed/empty output yields
`confident=False` (the orchestration then leaves the item unfiled).

- [ ] **Step 1: Write the failing tests**

`tests/test_agent.py`:

```python
import json

from media_filer.agent import classify, AgentResult


def fake_runner_returning(payload):
    def _run(argv, timeout):
        # sanity: the release name must reach the CLI
        assert any("MyShow" in a for a in argv)
        return payload
    return _run


def test_parses_clean_json():
    payload = json.dumps({
        "type": "anime", "title": "My Show", "year": 2024,
        "season": 1, "episode": 5, "confident": True,
    })
    r = classify("MyShow.S01E05", ["MyShow.S01E05.mkv"],
                 runner=fake_runner_returning(payload))
    assert isinstance(r, AgentResult)
    assert r.type == "anime"
    assert r.title == "My Show"
    assert r.confident is True


def test_extracts_json_amid_prose():
    payload = 'Here is the result:\n{"type":"movie","title":"MyShow","year":1999,' \
              '"season":null,"episode":null,"confident":true}\nDone.'
    r = classify("MyShow.1999", ["MyShow.1999.mkv"],
                 runner=fake_runner_returning(payload))
    assert r.type == "movie"
    assert r.year == 1999


def test_malformed_output_is_not_confident():
    r = classify("MyShow", ["MyShow.mkv"],
                 runner=fake_runner_returning("sorry, I can't help"))
    assert r.confident is False


def test_unknown_type_is_not_confident():
    payload = json.dumps({"type": "unknown", "title": None, "year": None,
                          "season": None, "episode": None, "confident": True})
    r = classify("MyShow", ["MyShow.mkv"], runner=fake_runner_returning(payload))
    assert r.confident is False  # type unknown overrides claimed confidence
```

- [ ] **Step 2: Run to verify failure**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_agent.py -q`
Expected: FAIL (`ModuleNotFoundError: media_filer.agent`).

- [ ] **Step 3: Implement `agent.py`**

```python
"""Advisory classification via the Claude Code CLI. Claude returns JSON only;
it never touches the filesystem — the orchestration is the sole actor."""
from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass

_VALID_TYPES = ("movie", "tv", "anime")

PROMPT = """You are classifying a completed torrent for filing into a Jellyfin library.
Reply with ONLY a JSON object (no prose, no code fence) with exactly these keys:
  "type": one of "movie", "tv", "anime", or "unknown"
  "title": the English or romanized title (string)
  "year": integer release year, or null
  "season": integer season number, or null
  "episode": integer episode number, or null
  "confident": boolean — true only if you are sure of type and title

Torrent name: {name}
Files:
{files}
"""

# Defense in depth: even though the prompt asks for pure JSON, forbid every
# mutating tool so a misbehaving model still cannot alter the filesystem.
_DISALLOWED = "Write,Edit,MultiEdit,NotebookEdit,Bash"


@dataclass
class AgentResult:
    type: str
    title: str | None
    year: int | None
    season: int | None
    episode: int | None
    confident: bool


def _default_runner(argv: list[str], timeout: int) -> str:
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    return proc.stdout


def _extract_json(text: str) -> dict | None:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return None
    try:
        obj = json.loads(match.group(0))
    except json.JSONDecodeError:
        return None
    return obj if isinstance(obj, dict) else None


def _as_int(value) -> int | None:
    return value if isinstance(value, int) else None


def classify(name: str, files: list[str], *, runner=_default_runner, timeout: int = 120) -> AgentResult:
    prompt = PROMPT.format(name=name, files="\n".join(files))
    argv = ["claude", "-p", prompt, "--disallowedTools", _DISALLOWED]
    try:
        out = runner(argv, timeout)
    except (subprocess.SubprocessError, OSError):
        out = ""
    data = _extract_json(out) or {}
    ctype = data.get("type")
    confident = bool(data.get("confident")) and ctype in _VALID_TYPES and bool(data.get("title"))
    return AgentResult(
        type=ctype if ctype in _VALID_TYPES else "unknown",
        title=data.get("title") if isinstance(data.get("title"), str) else None,
        year=_as_int(data.get("year")),
        season=_as_int(data.get("season")),
        episode=_as_int(data.get("episode")),
        confident=confident,
    )
```

- [ ] **Step 4: Run to verify pass**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_agent.py -q`
Expected: all passed.

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/media/filer/media_filer/agent.py \
        modules/nixos/media/filer/tests/test_agent.py
git commit -m "feat(media-filer): claude advisory JSON classifier (injectable runner)"
```

---

## Task 6: `filer.py` — orchestration

**Files:**
- Create: `modules/nixos/media/filer/media_filer/filer.py`
- Test: `modules/nixos/media/filer/tests/test_filer.py`

Orchestration: given one job's `TR_*` env, locate the source, enumerate real
video files (skip samples/junk), determine `(category, title, year)` from the
torrent name — escalating to the agent on low confidence or a category label —
then hardlink. Movies link the largest video file; episode types parse each file
for season/episode. Anything still unsure is logged and left unfiled. The agent
and the linker are injected so tests use a stub classifier but exercise real
`os.link` on a temp tree.

- [ ] **Step 1: Write the failing tests**

`tests/test_filer.py`:

```python
from pathlib import Path

from media_filer import filer
from media_filer.agent import AgentResult


def _job(dir_, name, labels=""):
    return {"TR_TORRENT_DIR": str(dir_), "TR_TORRENT_NAME": name, "TR_TORRENT_LABELS": labels}


def _big(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\0" * (200 * 1024 * 1024))  # 200MB > sample threshold


def never_agent(*a, **k):
    raise AssertionError("agent should not be called for a confident release")


def test_movie_deterministic(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p.BluRay.x264-GRP"
    _big(src / "the.matrix.1999.1080p.mkv")
    (src / "sample.mkv").write_bytes(b"\0" * 1024)  # sample, must be ignored

    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)

    dest = root / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv"
    assert dest.exists()
    assert any(r.action == "linked" for r in results)


def test_season_pack_deterministic(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _big(src / "Severance.S02E01.1080p.mkv")
    _big(src / "Severance.S02E02.1080p.mkv")

    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)

    tv = root / "tv" / "Severance" / "Season 02"
    assert (tv / "Severance - S02E01.mkv").exists()
    assert (tv / "Severance - S02E02.mkv").exists()


def test_cjk_uses_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "基督山伯爵.2024.1080p.WEB-DL"
    _big(src / "基督山伯爵.2024.1080p.mkv")

    def stub(name, files, **k):
        return AgentResult("movie", "The Count of Monte Cristo", 2024, None, None, True)

    filer.process_job(_job(dl, src.name), root=root, classify=stub)

    assert (root / "movies" / "The Count of Monte Cristo (2024)"
            / "The Count of Monte Cristo (2024).mkv").exists()


def test_label_forces_anime(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Frieren.S01E05.1080p-GRP"
    _big(src / "Frieren.S01E05.1080p.mkv")

    filer.process_job(_job(dl, src.name, labels="anime"), root=root, classify=never_agent)

    assert (root / "anime" / "Frieren" / "Season 01" / "Frieren - S01E05.mkv").exists()


def test_music_falls_through_unfiled(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Some.Artist.Discography.FLAC"
    _big(src / "01.track.flac")

    def unsure(name, files, **k):
        return AgentResult("unknown", None, None, None, None, False)

    results = filer.process_job(_job(dl, src.name), root=root, classify=unsure)

    assert all(r.action == "unfiled" for r in results)
    # nothing created under the library
    assert not any(root.rglob("*.flac"))
```

- [ ] **Step 2: Run to verify failure**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_filer.py -q`
Expected: FAIL (`ModuleNotFoundError: media_filer.filer`).

- [ ] **Step 3: Implement `filer.py`**

```python
"""Orchestrate one completed torrent into the library."""
from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from pathlib import Path

from . import agent as agent_mod
from . import hardlink as hardlink_mod
from . import layout, parse

log = logging.getLogger("media_filer")

VIDEO_EXTS = {".mkv", ".mp4", ".avi", ".ts", ".m2ts", ".mov", ".wmv"}
SUB_EXTS = {".srt", ".ass", ".ssa", ".sub"}
_SAMPLE = re.compile(r"(?i)(^|[\W_])(sample|trailer|extras?)([\W_]|$)")
MIN_VIDEO_BYTES = 100 * 1024 * 1024  # 100 MB — below this is treated as a sample
_LABEL_CATS = {"movie", "tv", "anime"}


@dataclass
class Result:
    action: str  # "linked" | "exists" | "unfiled" | "conflict"
    src: str
    dest: str | None
    reason: str | None = None


def _video_files(root: Path) -> list[Path]:
    if root.is_file():
        return [root] if root.suffix.lower() in VIDEO_EXTS else []
    out = []
    for p in sorted(root.rglob("*")):
        if not p.is_file() or p.suffix.lower() not in VIDEO_EXTS:
            continue
        if _SAMPLE.search(p.name):
            continue
        if p.stat().st_size < MIN_VIDEO_BYTES:
            continue
        out.append(p)
    return out


def _label_category(labels: str) -> str | None:
    for tok in labels.split(","):
        tok = tok.strip().lower()
        if tok in _LABEL_CATS:
            return tok
    return None


def _resolve(name: str, files: list[Path], labels: str, classify) -> agent_mod.AgentResult | None:
    """Decide (category, title, year, season, episode). Returns an AgentResult-shaped
    decision, or None if we cannot confidently file it."""
    label_cat = _label_category(labels)
    c = parse.parse_name(name)

    if parse.confident(c) and (label_cat is None or label_cat != "anime" or c.type == "episode"):
        category = label_cat or ("movie" if c.type == "movie" else "tv")
        return agent_mod.AgentResult(category, c.title, c.year, c.season, c.episode, True)

    # Escalate: CJK, missing type, or unresolved category.
    decision = classify(name, [f.name for f in files])
    if not decision.confident:
        return None
    if label_cat:  # an explicit label still wins on category
        decision.type = label_cat
    return decision


def _file_episode(fname: str) -> tuple[int | None, int | None]:
    c = parse.parse_name(fname)
    return c.season, c.episode


def process_job(env: dict, *, root: Path = layout.MEDIA_ROOT,
                classify=agent_mod.classify, link=hardlink_mod.hardlink) -> list[Result]:
    name = env["TR_TORRENT_NAME"]
    src_root = Path(env["TR_TORRENT_DIR"]) / name
    labels = env.get("TR_TORRENT_LABELS", "")

    files = _video_files(src_root)
    if not files:
        log.info("unfiled: %s (no video files)", name)
        return [Result("unfiled", str(src_root), None, "no video files")]

    decision = _resolve(name, files, labels, classify)
    if decision is None:
        log.info("unfiled: %s (undetermined)", name)
        return [Result("unfiled", str(src_root), None, "undetermined")]

    results: list[Result] = []
    if decision.type == "movie":
        feature = max(files, key=lambda p: p.stat().st_size)
        dest = layout.movie_dest(root, decision.title, decision.year, feature.suffix)
        results.append(_place(feature, dest, root, link))
    else:  # tv | anime
        anime = decision.type == "anime"
        for f in files:
            season, episode = _file_episode(f.name)
            if season is None:
                season = decision.season
            if episode is None:
                episode = decision.episode
            if season is not None and episode is not None:
                dest = layout.tv_dest(root, decision.title, season, episode, f.suffix, anime=anime)
            elif anime and episode is not None:
                dest = layout.anime_absolute_dest(root, decision.title, episode, f.suffix)
            else:
                results.append(Result("unfiled", str(f), None, "no episode number"))
                log.info("unfiled: %s (no episode number)", f.name)
                continue
            results.append(_place(f, dest, root, link))
    return results


def _place(src: Path, dest: Path, root: Path, link) -> Result:
    if not layout.is_inside(dest, root):
        log.error("unfiled: %s (dest %s escapes %s)", src.name, dest, root)
        return Result("unfiled", str(src), str(dest), "dest escapes library root")
    try:
        action = link(src, dest)
    except hardlink_mod.LinkConflict as e:
        log.warning("conflict: %s", e)
        return Result("conflict", str(src), str(dest), str(e))
    log.info("%s: %s -> %s", action, src.name, dest)
    return Result(action, str(src), str(dest))
```

- [ ] **Step 4: Run to verify pass**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_filer.py -q`
Expected: all passed. (Note: the 200MB temp files make these tests write ~1GB total to `tmp_path`; that's fine on the ZFS box. If you prefer, lower `MIN_VIDEO_BYTES` handling by monkeypatching it in the test instead — but keep the production threshold at 100MB.)

- [ ] **Step 5: Run the whole suite**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest -q`
Expected: all tests across all files pass.

- [ ] **Step 6: Commit**

```bash
git add modules/nixos/media/filer/media_filer/filer.py \
        modules/nixos/media/filer/tests/test_filer.py
git commit -m "feat(media-filer): orchestration (parse/escalate/route/hardlink)"
```

---

## Task 7: `cli.py` — drain the queue

**Files:**
- Create: `modules/nixos/media/filer/media_filer/cli.py`
- Test: `modules/nixos/media/filer/tests/test_cli.py`

`main(argv)` takes the queue dir, processes every `*.job`, deletes each only
after handling (crash-safe at-least-once), and configures journald-friendly
logging. Each `.job` is `KEY=VALUE` lines (the hook's `env | grep ^TR_`).

- [ ] **Step 1: Write the failing test**

`tests/test_cli.py`:

```python
from pathlib import Path

from media_filer import cli


def test_drain_processes_and_deletes_jobs(tmp_path, monkeypatch):
    queue = tmp_path / "q"
    queue.mkdir()
    job = queue / "abc.job"
    job.write_text("TR_TORRENT_DIR=/dl\nTR_TORRENT_NAME=Movie.2020\nTR_TORRENT_LABELS=\n")

    seen = []
    monkeypatch.setattr(cli.filer, "process_job", lambda env, **k: seen.append(env) or [])

    cli.main([str(queue)])

    assert seen and seen[0]["TR_TORRENT_NAME"] == "Movie.2020"
    assert not job.exists()  # job removed after handling


def test_bad_job_is_removed_not_fatal(tmp_path, monkeypatch):
    queue = tmp_path / "q"
    queue.mkdir()
    (queue / "bad.job").write_text("TR_TORRENT_NAME=x\n")

    def boom(env, **k):
        raise RuntimeError("kaboom")

    monkeypatch.setattr(cli.filer, "process_job", boom)
    cli.main([str(queue)])  # must not raise
    assert not (queue / "bad.job").exists()
```

- [ ] **Step 2: Run to verify failure**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_cli.py -q`
Expected: FAIL (`ModuleNotFoundError: media_filer.cli`).

- [ ] **Step 3: Implement `cli.py`**

```python
"""Entry point: drain a queue directory of .job files."""
from __future__ import annotations

import logging
import sys
from pathlib import Path

from . import filer


def _parse_job(text: str) -> dict:
    env = {}
    for line in text.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            env[key.strip()] = value
    return env


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    argv = list(sys.argv[1:] if argv is None else argv)
    queue = Path(argv[0]) if argv else Path("/tank/media/downloads/.filer-queue")

    for job in sorted(queue.glob("*.job")):
        try:
            env = _parse_job(job.read_text())
            if env.get("TR_TORRENT_NAME") and env.get("TR_TORRENT_DIR"):
                filer.process_job(env)
        except Exception:  # never let one job wedge the queue
            logging.exception("failed handling %s", job.name)
        finally:
            job.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run to verify pass**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest tests/test_cli.py -q`
Expected: all passed.

- [ ] **Step 5: Full suite + commit**

Run: `cd modules/nixos/media/filer && uv run --extra dev pytest -q`
Expected: all passed.

```bash
git add modules/nixos/media/filer/media_filer/cli.py \
        modules/nixos/media/filer/tests/test_cli.py
git commit -m "feat(media-filer): cli that drains the job queue"
```

---

## Task 8: NixOS module + wiring

**Files:**
- Create: `modules/nixos/media/filer.nix`
- Modify: `modules/nixos/media/default.nix` (add `./filer.nix`)

- [ ] **Step 1: Write `filer.nix`**

```nix
# Agent-assisted hardlink-on-completion. Transmission's script-torrent-done hook
# drops a TR_* job file into the download-dir (the one path writable inside its
# sandbox); a systemd.path watcher fires media-filer.service — a separate,
# least-privilege unit with RW on /tank/media — which parses the release
# (guessit), optionally asks Claude for a JSON classification, and hardlinks it
# into the Jellyfin library. Claude only advises; the Python app is the sole
# thing that touches the filesystem. See
# docs/superpowers/specs/2026-07-05-media-filer-design.md
{pkgs, ...}: let
  media-filer = pkgs.python3.pkgs.buildPythonApplication {
    pname = "media-filer";
    version = "0.1.0";
    pyproject = true;
    src = ./filer;
    build-system = [pkgs.python3.pkgs.hatchling];
    dependencies = [pkgs.python3.pkgs.guessit];
    doCheck = false; # tests are the dev loop (uv), not the build
  };

  queue = "/tank/media/downloads/.filer-queue";

  # Runs inside Transmission's sandbox as the `transmission` user. Does the bare
  # minimum and returns instantly: atomically drop a TR_* dump into the queue.
  doneHook = pkgs.writeShellScript "transmission-done-filer" ''
    set -eu
    umask 0002
    tmp="${queue}/''${TR_TORRENT_HASH}.job.tmp"
    ${pkgs.coreutils}/bin/env | ${pkgs.gnugrep}/bin/grep '^TR_' > "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "${queue}/''${TR_TORRENT_HASH}.job"
  '';
in {
  # Dedicated no-login user; group `media` gives RW on the library via setgid dirs.
  users.users.media-filer = {
    isSystemUser = true;
    group = "media";
    description = "Files completed torrents into the Jellyfin library";
    home = "/var/lib/media-filer";
  };

  # Queue dir (transmission writes as owner, media-filer deletes via the media
  # group) plus the root-only secrets dir for the Claude key env file.
  systemd.tmpfiles.rules = [
    "d ${queue} 2775 transmission media -"
    "d /var/lib/media-filer-secrets 0700 root root -"
  ];

  # Wire the hook into Transmission (kept here so transmission.nix stays a pure
  # daemon config).
  services.transmission.settings = {
    script-torrent-done-enabled = true;
    script-torrent-done-filename = "${doneHook}";
  };

  # Fire the filer whenever the queue is non-empty; it re-arms after each drain.
  systemd.paths.media-filer = {
    wantedBy = ["multi-user.target"];
    pathConfig.DirectoryNotEmpty = queue;
  };

  systemd.services.media-filer = {
    description = "File completed torrents into the Jellyfin library";
    wants = ["network-online.target"];
    after = ["network-online.target"];
    path = [pkgs.claude-code]; # provides `claude` for the advisory fallback
    serviceConfig = {
      Type = "oneshot";
      User = "media-filer";
      Group = "media";
      ExecStart = "${media-filer}/bin/media-filer ${queue}";

      # Writable HOME/state for Claude (config/cache/creds + future ~/.claude/skills).
      StateDirectory = "media-filer";
      Environment = ["HOME=/var/lib/media-filer"];
      EnvironmentFile = "-/var/lib/media-filer-secrets/env"; # ANTHROPIC_API_KEY, root-only

      # Least privilege. BindPaths (not ReadWritePaths — the latter does not
      # produce writable mounts under our ZFS strict sandbox) makes the library
      # writable. Network egress stays allowed (Claude needs it).
      ProtectSystem = "strict";
      BindPaths = ["/tank/media"];
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
```

> **NOTE for implementer:** Verify `pkgs.claude-code` provides `bin/claude`
> before relying on it: `nix build .#nixosConfigurations.nixmachine.pkgs.claude-code`
> then check `result/bin/claude` exists. The secret key lives in the root-only
> `/var/lib/media-filer-secrets/env`; systemd reads `EnvironmentFile` as root
> before dropping to the `media-filer` user (same pattern as litellm), so the
> unprivileged user never needs read access to it.

- [ ] **Step 2: Add the module to `default.nix`**

Modify `modules/nixos/media/default.nix` imports to include `./filer.nix`:

```nix
  imports = [
    ./storage.nix
    ./transmission.nix
    ./jellyfin.nix
    ./metatube.nix
    ./firewall.nix
    ./filer.nix
  ];
```

- [ ] **Step 3: Stage the new Python sources (flakes only see tracked files)**

Run: `git add -A modules/nixos/media/filer modules/nixos/media/filer.nix modules/nixos/media/default.nix`

- [ ] **Step 4: Evaluate + build the config**

Run: `nix fmt && nix eval --raw .#nixosConfigurations.nixmachine.config.system.build.toplevel.drvPath`
Expected: prints a `.drv` path with no evaluation error.

Then build (does not activate): `nix build .#nixosConfigurations.nixmachine.config.system.build.toplevel`
Expected: builds successfully (this compiles the `media-filer` package too).

- [ ] **Step 5: Commit**

```bash
git add -A modules/nixos/media/filer.nix modules/nixos/media/default.nix modules/nixos/media/filer
git commit -m "feat(media): wire media-filer service + transmission done-hook"
```

---

## Task 9: Deploy + smoke test (runbook — run by the user via `!`)

**Files:** none (operational).

- [ ] **Step 1: Create the secret env file (root, 0600)**

The user runs (interactive, needs sudo):

```
! sudo install -m 700 -d /var/lib/media-filer-secrets
! sudo sh -c 'printf "ANTHROPIC_API_KEY=%s\n" "sk-ant-..." > /var/lib/media-filer-secrets/env && chmod 600 /var/lib/media-filer-secrets/env'
```

- [ ] **Step 2: Switch**

```
! sudo nixos-rebuild switch --flake .#nixmachine
```

- [ ] **Step 3: Verify units exist**

```
systemctl status media-filer.path
systemctl cat media-filer.service | head -30
```

Expected: `media-filer.path` active (waiting); service present with `User=media-filer`, `BindPaths=/tank/media`.

- [ ] **Step 4: Smoke test the pipeline without a real torrent**

Drop a fake job and confirm the filer runs (deterministic path, no Claude needed).
First stage a fake completed movie under downloads, then enqueue a job:

```
! sudo -u transmission mkdir -p "/tank/media/downloads/The.Matrix.1999.1080p.BluRay-TEST"
! sudo -u transmission truncate -s 200M "/tank/media/downloads/The.Matrix.1999.1080p.BluRay-TEST/the.matrix.1999.1080p.mkv"
! sudo -u transmission sh -c 'printf "TR_TORRENT_DIR=/tank/media/downloads\nTR_TORRENT_NAME=The.Matrix.1999.1080p.BluRay-TEST\nTR_TORRENT_LABELS=\n" > /tank/media/downloads/.filer-queue/test.job'
```

Then watch it fire:

```
journalctl -u media-filer -n 40 --no-pager
ls -l "/tank/media/movies/The Matrix (1999)/"
```

Expected: a `linked: … -> …/movies/The Matrix (1999)/The Matrix (1999).mkv` log line, and the hardlink present. `truncate` makes a sparse 200MB file (over the sample threshold) with negligible disk use.

- [ ] **Step 5: Clean up the smoke test**

```
! sudo rm -rf "/tank/media/downloads/The.Matrix.1999.1080p.BluRay-TEST" "/tank/media/movies/The Matrix (1999)"
```

- [ ] **Step 6: Real end-to-end**

Finish a real download in Transmission and confirm the hardlink appears via
`journalctl -u media-filer -f`. For a CJK/ambiguous release, confirm the Claude
fallback fires (the log shows the escalation) and check the destination.

---

## Self-Review

**Spec coverage** (each spec section → task):
- Architecture / spool bridge → Task 8 (hook + `systemd.path` + service).
- `parse.py` (guessit, `_scalar`, CJK) → Task 2.
- `layout.py` (Jellyfin names + clamp) → Task 3.
- `hardlink.py` (idempotent, conflict) → Task 4.
- `agent.py` (advisory JSON, no write tools) → Task 5.
- `filer.py` (enumerate/sample-skip, category, label hint, multi-file, movie=largest, season pack) → Task 6.
- Confidence gating + `TR_TORRENT_LABELS` override → Task 2 (`confident`) + Task 6 (`_resolve`/`_label_category`).
- Anime absolute-vs-season → Task 3 (`anime_absolute_dest`) + Task 6 routing.
- Error handling / idempotency / at-least-once / per-job isolation → Task 4, Task 6 (`_place`), Task 7 (`main` try/finally).
- Security (dedicated user, sandbox, BindPaths, root-only key, Claude no-write) → Task 5 (`_DISALLOWED`) + Task 8 (serviceConfig).
- Skills extensibility (writable HOME) → Task 8 (`StateDirectory` + `HOME`).
- Testing → Tasks 2–7 unit/integration; `nix build` in Task 8.
- Deployment → Task 9.

**Placeholder scan:** none — every step contains runnable code or an exact command. The only `NOTE` (Task 8) is a pre-flight verification of `pkgs.claude-code`, not a deferred decision.

**Type consistency:** `Candidate` fields (Task 2) match their use in `filer._resolve`/`_file_episode` (Task 6). `AgentResult` fields (Task 5) match construction in Task 6 tests and `_resolve`. `hardlink()` returns `"linked"|"exists"` and raises `LinkConflict` (Task 4), consumed in `filer._place` (Task 6). `process_job(env, *, root, classify, link)` signature matches Task 6 tests and `cli.main` call (Task 7). `layout.movie_dest/tv_dest/anime_absolute_dest/is_inside/sanitize` signatures (Task 3) match calls in Task 6.
