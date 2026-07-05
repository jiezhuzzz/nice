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
