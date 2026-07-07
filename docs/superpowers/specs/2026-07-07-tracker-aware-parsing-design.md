# Media Filer — Tracker-Aware Parsing (Design)

**Status:** approved · **Date:** 2026-07-07 · **Host:** nixmachine

## Problem

The filer parses a release name with `guessit`, and escalates to the Claude
agent whenever `parse.confident()` fails — which it does for every release from
a private tracker like **HDSky**: the name leads with a CJK title (caught by
`parse.is_cjk`, forcing escalation) and uses `@group` instead of `-group` (so
`guessit` misreads the group). Result: essentially *every* HDSky torrent takes a
Claude round-trip — latency, cost, and a network dependency inside a sandboxed
oneshot — even though HDSky's naming is rigid and fully known.

A private tracker's convention is deterministic. If the filer knows which
tracker a torrent came from, it can parse the name with a tiny tracker-specific
regex and skip the agent entirely.

## Goal / Non-goals

- **Goal:** a deterministic, tracker-aware front-layer that resolves known-format
  releases before `guessit`/Claude, cutting agent escalations to ~zero for
  covered trackers. Start with **HDSky** as the proof of concept (1–2 trackers).
- **Non-goal:** replacing `guessit`. It stays the parser for everything not from
  a recognized tracker.
- **Non-goal:** any regression for non-covered torrents — the existing
  `guessit → confident() → Claude` path must run unchanged when no tracker
  parser matches.
- **Non-goal:** Nix-level config plumbing for the tracker table (a domain is not
  a secret; hardcode it in the Python).

## Approach

**Regex registry** (chosen over per-tracker `guessit` config or a
preprocess+`guessit` hybrid): the conventions are rigid, and the hard parts
(CJK prefix, `@group`, dotted `S01.E05`) are trivial for an anchored regex but
painful to coax out of a fuzzy parser. Each tracker parser returns the existing
`parse.Candidate` shape, so it drops into the current flow with no downstream
changes.

## Architecture

```
process_job(env)
  ├─ tracker = trackers.tracker_for(env["TR_TORRENT_TRACKERS"])   # host → id, or None
  └─ _resolve(name, files, labels, tracker, classify)
       ├─ if tracker:
       │     c = trackers.release(tracker, name)      # Candidate | None
       │     if c and confident(c) and compatible(label, c.type):
       │         → file it, NO guessit, NO Claude
       ├─ (fallthrough) c = parse.parse_name(name)    # existing guessit path
       │     if confident(c) and compatible: → file
       └─ else: classify(...)                         # existing Claude fallback

per TV file:
  _file_episode(fname, tracker)
    ├─ if tracker: trackers.file(tracker, fname)      # (season, episode) | None
    └─ else: parse.parse_name(fname)                  # existing
```

Tracker identity comes from `TR_TORRENT_TRACKERS`, which Transmission 4.1.3
exposes to the done-script and the hook already dumps into the `.job` file. Only
the **hostname** is used; the passkey embedded in the announce URL is ignored.

## Components

### New — `media_filer/trackers.py`

- `tracker_for(trackers_env: str) -> str | None` — split the announce list,
  extract hostnames, return the first id found in the `host → id` table.
- `_HOSTS: dict[str, str]` — hostname → tracker id (HDSky's announce host here).
- `_REGISTRY: dict[str, Parser]` — `{"hdsky": HDSky()}`.
- `release(tracker, name) -> Candidate | None` and
  `file(tracker, name) -> tuple[int|None, int|None] | None` — registry dispatch;
  return `None` on no-match so callers fall back cleanly.
- `HDSky` — three anchored regexes (movie / tv-dir / tv-file). Title = the tokens
  between the leading CJK token and the landmark, dots→spaces. Movie-vs-TV
  decided by presence of an `S\d+` token.

### Edits — `media_filer/filer.py`

- `process_job`: compute `tracker` from `TR_TORRENT_TRACKERS`; thread it into
  `_resolve` and `_file_episode`.
- `_resolve`: gain a `tracker` param; try `trackers.release` first, gated by the
  existing `confident()` and `_compatible()` checks; otherwise unchanged.
- `_file_episode`: gain a `tracker` param; try `trackers.file` first, else
  `guessit`.

### Optional, separable — `filer.nix`

Strip the passkey from `TR_TORRENT_TRACKERS` in the done-hook so announce URLs
with secrets stop being written to the queue on disk. Own commit; independent of
the parsing feature.

## HDSky convention (resolved)

- `movie`: `{CJK}.{English title…}.{year}.{resolution}.{type}.{qualities…}@{group}`
- `tv dir` (season pack): `{CJK}.{English title…}.S{season}.{year}.…@{group}` — season only.
- `tv file`: `{CJK}.{English title…}.S{season}.E{episode}.{year}.…@{group}` — carries episode.
- CJK title is a single leading dot-token, always present. English title always
  present. File under the English title (dots→spaces).

## Confidence & fallback

A tracker parse is confident under the same rules as `parse.confident`: a
non-CJK title plus a year (movie) or a season (tv). A confident, label-compatible
tracker `Candidate` short-circuits to filing; anything else — unknown tracker,
non-matching name, low-confidence, contradicting label — falls through to the
untouched `guessit → Claude` pipeline. Defense-in-depth is preserved.

## Testing (TDD, uv dev loop)

- `tests/test_trackers.py`:
  - `tracker_for`: real announce URL(s) → `"hdsky"`; unknown host → `None`.
  - `HDSky.release`: real movie + tv names → expected `Candidate`; season-pack
    dir → season with `episode=None`; non-matching name → `None`.
  - `HDSky.file`: real per-episode file name → `(season, episode)`.
- Integration (`test_filer.py`): a `process_job` on an HDSky job files correctly
  **without invoking the agent** (assert `classify` is not called).

## Inputs required before implementation

These are data, not open design questions — supplied when we write the tests:

1. **HDSky announce hostname** (bare host) → the one entry in `_HOSTS`.
2. **4–6 real HDSky release names** (2 movies, 2 TV episodes, 1 season-pack dir +
   2 file names inside) → the `test_trackers.py` fixtures that pin the regexes.
