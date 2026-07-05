"""Find sidecar subtitle files, match them to a video, and compute Jellyfin
sidecar destination names (video stem + `.lang[.flag]` + sub extension)."""
from __future__ import annotations

import re
from pathlib import Path

import guessit

from . import parse

SUB_EXTS = {".srt", ".ass", ".ssa", ".sub", ".vtt", ".idx"}
_SAMPLE = re.compile(r"(?i)(^|[\W_])(sample|trailer)([\W_]|$)")
_FLAGS = ("forced", "sdh", "cc")


def find_subtitles(root: Path) -> list[Path]:
    """All subtitle files under a torrent dir (siblings + Subs/ subfolders)."""
    if root.is_file():
        return [root] if root.suffix.lower() in SUB_EXTS else []
    out = []
    for p in sorted(root.rglob("*")):
        if p.is_file() and p.suffix.lower() in SUB_EXTS and not _SAMPLE.search(p.name):
            out.append(p)
    return out


def language_tail(name: str) -> str:
    """A `.lang[.flag...]` suffix from a subtitle filename, or "" if none.
    Language via guessit's subtitle_language; forced/sdh/cc via a name scan
    (guessit does not capture those)."""
    g = guessit.guessit(name)
    parts: list[str] = []
    lang = g.get("subtitle_language")
    if lang is not None:
        code = getattr(lang, "alpha2", None) or getattr(lang, "alpha3", None)
        if code:
            parts.append(str(code))
    for flag in _FLAGS:
        if re.search(rf"(?i)(?<![a-z]){flag}(?![a-z])", name):
            parts.append(flag)
    return "".join("." + p for p in parts)


def matches_episode(sub: Path, season, episode) -> bool:
    """True if the subtitle's parsed episode equals `episode` and its season is
    `season` or absent (falls back to the video's season)."""
    if episode is None:
        return False
    c = parse.parse_name(sub.name)
    if c.episode != episode:
        return False
    return c.season == season or c.season is None


def subtitle_dest(video_dest: Path, sub: Path, taken: set[Path]) -> Path:
    """Sidecar dest: the video dest's stem + language tail + the sub's extension,
    de-duplicated against `taken` (e.g. two same-language tracks -> `.2`)."""
    base = video_dest.stem
    tail = language_tail(sub.name)
    ext = sub.suffix.lower()
    candidate = video_dest.with_name(f"{base}{tail}{ext}")
    if candidate not in taken:
        return candidate
    i = 2
    while True:
        candidate = video_dest.with_name(f"{base}{tail}.{i}{ext}")
        if candidate not in taken:
            return candidate
        i += 1
