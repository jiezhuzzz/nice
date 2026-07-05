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
