# Tracker-Aware Parsing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic, per-tracker parsing front-layer to media-filer so releases from a known private tracker (HDSky first) are filed without a Claude round-trip.

**Architecture:** A new `trackers.py` module holds a `host → tracker id` table and a registry of per-tracker regex parsers that each return the existing `parse.Candidate` shape. `filer.py` identifies the tracker from `TR_TORRENT_TRACKERS`, tries the tracker parser before `guessit`, and falls through to the untouched `guessit → Claude` pipeline on any miss.

**Tech Stack:** Python 3.11+, `re`, `urllib.parse`; pytest via `uv`. No new dependencies.

**Working directory:** all commands run from `modules/nixos/media/filer/`.

**Spec:** `docs/superpowers/specs/2026-07-07-tracker-aware-parsing-design.md`

> **Fixture note:** The HDSky names below are structurally faithful to the confirmed template (single leading CJK token · always-present English title · `@group` · dotted `S01.E05`). Replace them with real HDSky release names when available — the regexes are anchored on the landmarks (`year`, `S\d+`, `@`) so real names should match, but real names may expose quirks worth a test. The `_HOSTS` match is a substring (`"hdsky"`), robust to the exact announce subdomain.

---

### Task 1: `tracker_for()` — identify the tracker from the announce list

**Files:**
- Create: `media_filer/trackers.py`
- Test: `tests/test_trackers.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_trackers.py
from media_filer import trackers


def test_tracker_for_hdsky_announce():
    env = "https://pt.hdsky.me/announce?passkey=SECRET"
    assert trackers.tracker_for(env) == "hdsky"


def test_tracker_for_multi_tracker_list_finds_known():
    env = "http://open.tracker.example/announce, https://pt.hdsky.me/announce?passkey=X"
    assert trackers.tracker_for(env) == "hdsky"


def test_tracker_for_unknown_host():
    assert trackers.tracker_for("https://tracker.example.org/announce") is None


def test_tracker_for_empty():
    assert trackers.tracker_for("") is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_trackers.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'media_filer.trackers'`

- [ ] **Step 3: Write minimal implementation**

```python
# media_filer/trackers.py
"""Deterministic per-tracker parsing. Private trackers use rigid naming
conventions, so a small tracker-specific regex resolves releases that guessit
mis-parses (CJK titles, @group), skipping the Claude agent."""
from __future__ import annotations

import re
from urllib.parse import urlparse

# hostname substring -> tracker id. A substring match tolerates announce
# subdomains (pt.hdsky.me, tracker.hdsky.me, ...). Domains are not secrets.
_HOSTS: dict[str, str] = {"hdsky": "hdsky"}


def tracker_for(trackers_env: str) -> str | None:
    """Map TR_TORRENT_TRACKERS (a whitespace/comma-separated list of announce
    URLs) to a known tracker id, or None. Only the hostname is inspected; the
    passkey in the URL is ignored."""
    if not trackers_env:
        return None
    for token in re.split(r"[\s,]+", trackers_env.strip()):
        host = (urlparse(token).hostname or "").lower()
        for needle, tid in _HOSTS.items():
            if needle in host:
                return tid
    return None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_trackers.py -v`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add media_filer/trackers.py tests/test_trackers.py
git commit -m "feat(filer): identify tracker from TR_TORRENT_TRACKERS announce host"
```

---

### Task 2: `HDSky.release()` — parse movie & TV release names

**Files:**
- Modify: `media_filer/trackers.py`
- Test: `tests/test_trackers.py`

- [ ] **Step 1: Write the failing test**

```python
# append to tests/test_trackers.py
from media_filer.parse import Candidate


def test_hdsky_movie():
    name = "满江红.Full.River.Red.2023.2160p.WEB-DL.H265.DDP5.1@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="movie", title="Full River Red", year=2023, season=None, episode=None
    )


def test_hdsky_tv_episode():
    name = "狂飙.The.Knockout.S01.E05.2023.1080p.WEB-DL.H264.AAC@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="episode", title="The Knockout", year=None, season=1, episode=5
    )


def test_hdsky_tv_season_pack_dir_has_no_episode():
    name = "狂飙.The.Knockout.S01.2023.1080p.WEB-DL.H264.AAC@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="episode", title="The Knockout", year=None, season=1, episode=None
    )


def test_hdsky_release_non_matching_returns_none():
    assert trackers.release("hdsky", "just-a-weird-name") is None


def test_release_unknown_tracker_returns_none():
    assert trackers.release("nope", "anything") is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_trackers.py -k "hdsky_movie or hdsky_tv or non_matching or unknown_tracker" -v`
Expected: FAIL — `AttributeError: module 'media_filer.trackers' has no attribute 'release'`

- [ ] **Step 3: Write minimal implementation**

```python
# add to media_filer/trackers.py (after the imports)
from .parse import Candidate

_YEAR = r"(?:19|20)\d{2}"


def _clean(title: str) -> str:
    return title.replace(".", " ").strip()


class HDSky:
    # Anchored on landmarks; the qualities blob between landmark and @group is
    # ignored. Leading [^.]+ is the single CJK title token.
    _MOVIE = re.compile(rf"^[^.]+\.(?P<title>.+?)\.(?P<year>{_YEAR})(?:\.|@)")
    _TV = re.compile(
        r"^[^.]+\.(?P<title>.+?)\.S(?P<season>\d{1,2})(?:\.E(?P<episode>\d{1,3}))?(?:\.|@|$)"
    )

    def release(self, name: str) -> Candidate | None:
        # TV first: a TV name also contains a year the movie regex would grab.
        m = self._TV.match(name)
        if m:
            ep = m.group("episode")
            return Candidate(
                type="episode",
                title=_clean(m.group("title")),
                year=None,
                season=int(m.group("season")),
                episode=int(ep) if ep else None,
            )
        m = self._MOVIE.match(name)
        if m:
            return Candidate(
                type="movie",
                title=_clean(m.group("title")),
                year=int(m.group("year")),
                season=None,
                episode=None,
            )
        return None


_REGISTRY: dict[str, HDSky] = {"hdsky": HDSky()}


def release(tracker: str, name: str) -> Candidate | None:
    parser = _REGISTRY.get(tracker)
    return parser.release(name) if parser else None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_trackers.py -v`
Expected: PASS (9 passed)

- [ ] **Step 5: Commit**

```bash
git add media_filer/trackers.py tests/test_trackers.py
git commit -m "feat(filer): parse HDSky movie and TV release names"
```

---

### Task 3: `HDSky.file()` — extract season/episode from a TV file name

**Files:**
- Modify: `media_filer/trackers.py`
- Test: `tests/test_trackers.py`

- [ ] **Step 1: Write the failing test**

```python
# append to tests/test_trackers.py
def test_hdsky_file_episode():
    fname = "狂飙.The.Knockout.S01.E05.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv"
    assert trackers.file("hdsky", fname) == (1, 5)


def test_hdsky_file_no_episode_returns_none():
    assert trackers.file("hdsky", "满江红.Full.River.Red.2023.1080p@HDSky.mkv") is None


def test_file_unknown_tracker_returns_none():
    assert trackers.file("nope", "whatever.mkv") is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `uv run pytest tests/test_trackers.py -k "file" -v`
Expected: FAIL — `AttributeError: module 'media_filer.trackers' has no attribute 'file'`

- [ ] **Step 3: Write minimal implementation**

```python
# add the _FILE pattern + method to the HDSky class, and the module-level file()

# inside class HDSky, alongside _MOVIE / _TV:
    _FILE = re.compile(r"\.S(?P<season>\d{1,2})\.E(?P<episode>\d{1,3})\b")

    def file(self, name: str) -> tuple[int | None, int | None] | None:
        m = self._FILE.search(name)
        if not m:
            return None
        return int(m.group("season")), int(m.group("episode"))


# module level, next to release():
def file(tracker: str, name: str) -> tuple[int | None, int | None] | None:
    parser = _REGISTRY.get(tracker)
    return parser.file(name) if parser else None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `uv run pytest tests/test_trackers.py -v`
Expected: PASS (12 passed)

- [ ] **Step 5: Commit**

```bash
git add media_filer/trackers.py tests/test_trackers.py
git commit -m "feat(filer): extract season/episode from HDSky file names"
```

---

### Task 4: Wire the tracker layer into `filer.py`

**Files:**
- Modify: `media_filer/filer.py` (`process_job`, `_resolve`, `_file_episode`)
- Test: `tests/test_filer.py`

- [ ] **Step 1: Write the failing integration tests**

```python
# append to tests/test_filer.py

def _hdsky_job(dir_, name):
    return {
        "TR_TORRENT_DIR": str(dir_),
        "TR_TORRENT_NAME": name,
        "TR_TORRENT_TRACKERS": "https://pt.hdsky.me/announce?passkey=SECRET",
    }


def test_hdsky_movie_skips_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "满江红.Full.River.Red.2023.2160p.WEB-DL.H265@HDSky"
    _mk(src / "满江红.Full.River.Red.2023.2160p.WEB-DL.H265@HDSky.mkv", 8192)
    # never_agent raises if the agent is consulted -> proves the tracker path won.
    results = filer.process_job(_hdsky_job(dl, src.name), root=root, classify=never_agent)
    dest = root / "movies" / "Full River Red (2023)" / "Full River Red (2023).mkv"
    assert dest.exists()
    assert any(r.action == "linked" for r in results)


def test_hdsky_season_pack_skips_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "狂飙.The.Knockout.S01.2023.1080p.WEB-DL.H264.AAC@HDSky"
    _mk(src / "狂飙.The.Knockout.S01.E01.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv")
    _mk(src / "狂飙.The.Knockout.S01.E02.2023.1080p.WEB-DL.H264.AAC@HDSky.mkv")
    filer.process_job(_hdsky_job(dl, src.name), root=root, classify=never_agent)
    tv = root / "tv" / "The Knockout" / "Season 01"
    assert (tv / "The Knockout - S01E01.mkv").exists()
    assert (tv / "The Knockout - S01E02.mkv").exists()
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `uv run pytest tests/test_filer.py -k hdsky -v`
Expected: FAIL — the agent is consulted (`AssertionError: agent should not be called`) because `filer.py` does not yet use the tracker layer.

- [ ] **Step 3: Modify `filer.py`**

Add the import near the top (with the other `from . import ...`):

```python
from . import trackers
```

Replace `_resolve` (currently `filer.py:65`) so it tries the tracker parser first:

```python
def _resolve(name: str, files: list[Path], labels: str, tracker: str | None, classify) -> agent_mod.AgentResult | None:
    """Decide (category, title, year, season, episode). Returns an AgentResult-shaped
    decision, or None if we cannot confidently file it."""
    label_cat = _label_category(labels)

    c = trackers.release(tracker, name) if tracker else None
    if c is None:
        c = parse.parse_name(name)

    if parse.confident(c) and _compatible(label_cat, c.type):
        category = label_cat or ("movie" if c.type == "movie" else "tv")
        return agent_mod.AgentResult(category, c.title, c.year, c.season, c.episode, True)

    # Escalate: CJK, missing type, unresolved category, or a label that
    # contradicts the parsed structure.
    decision = classify(name, [f.name for f in files])
    if not decision.confident:
        return None
    if label_cat:  # an explicit label still wins on category
        decision.type = label_cat
    return decision
```

Replace `_file_episode` (currently `filer.py:85`) to try the tracker file parser first:

```python
def _file_episode(fname: str, tracker: str | None = None) -> tuple[int | None, int | None]:
    if tracker:
        r = trackers.file(tracker, fname)
        if r is not None:
            return r
    c = parse.parse_name(fname)
    return c.season, c.episode
```

In `process_job` (currently `filer.py:90`), compute the tracker and thread it through. Change the body near the top and the two call sites:

```python
def process_job(env: dict, *, root: Path = layout.MEDIA_ROOT,
                classify=agent_mod.classify, link=hardlink_mod.hardlink) -> list[Result]:
    name = env["TR_TORRENT_NAME"]
    src_root = Path(env["TR_TORRENT_DIR"]) / name
    labels = env.get("TR_TORRENT_LABELS", "")
    tracker = trackers.tracker_for(env.get("TR_TORRENT_TRACKERS", ""))
    ...
    decision = _resolve(name, files, labels, tracker, classify)
```

And in the `tv | anime` loop, pass the tracker to `_file_episode` (currently `filer.py:122`):

```python
            season, episode = _file_episode(f.name, tracker)
```

- [ ] **Step 4: Run the full suite to verify pass + no regressions**

Run: `uv run pytest -v`
Expected: PASS — the two new `hdsky` tests pass and every existing test (movie/season-pack/CJK-agent/etc.) still passes.

- [ ] **Step 5: Commit**

```bash
git add media_filer/filer.py tests/test_filer.py
git commit -m "feat(filer): use tracker-aware parsing before guessit/Claude"
```

---

### Task 5 (optional, separable): strip the passkey from the done-hook

Independent of the parsing feature. The done-hook dumps every `TR_*` var — including `TR_TORRENT_TRACKERS`, whose announce URLs embed the private passkey — into a `.job` file on disk. We only need hostnames, so redact the passkey at the source.

**Files:**
- Modify: `modules/nixos/media/filer.nix` (the `doneHook` `writeShellScript`)

- [ ] **Step 1: Redact in the hook**

In `doneHook`, replace the plain env dump with one that strips `passkey=`/`authkey=` query values from `TR_TORRENT_TRACKERS` before writing:

```bash
  # dump TR_* but redact tracker passkeys (announce URLs carry the private key)
  ${pkgs.coreutils}/bin/env | ${pkgs.gnugrep}/bin/grep '^TR_' \
    | ${pkgs.gnused}/bin/sed -E 's/(passkey|authkey)=[^&[:space:],]*/\1=REDACTED/g' > "$tmp"
```

- [ ] **Step 2: Verify the module still evaluates**

Run (from repo root): `nix eval --raw ".#nixosConfigurations.nixmachine.config.systemd.services.media-filer.serviceConfig.ExecStart" >/dev/null && echo OK`
Expected: `OK` (the filer module evaluates; `gnused` is a valid `pkgs` attr).

- [ ] **Step 3: Commit**

```bash
git add modules/nixos/media/filer.nix
git commit -m "fix(filer): redact tracker passkeys from queued job dumps"
```

---

## Self-Review

**Spec coverage:**
- Tracker identification (`tracker_for`, host→id, hostname-only) → Task 1 ✓
- Regex registry + per-tracker `Candidate` parser → Task 2 ✓
- Per-file season/episode extraction → Task 3 ✓
- `filer.py` integration at `_resolve` / `_file_episode` / `process_job`, fallback preserved → Task 4 ✓
- Confidence reuses `parse.confident`; label compatibility preserved → Task 4 (`_resolve` unchanged gates) ✓
- Testing: `test_trackers.py` unit + `test_filer.py` "no agent" integration → Tasks 1–4 ✓
- Optional passkey strip in `filer.nix` → Task 5 ✓

**Placeholder scan:** No TBD/TODO in steps; every code step shows complete code. Fixture names are flagged as real-name-replaceable, which is data, not a logic gap.

**Type consistency:** `trackers.release/file` signatures match calls in `filer.py`; `Candidate(type in {"movie","episode"})` matches `_resolve`'s existing `c.type` handling; `_file_episode(fname, tracker=None)` default keeps existing callers valid; `tracker` param on `_resolve` threaded from `process_job`.
