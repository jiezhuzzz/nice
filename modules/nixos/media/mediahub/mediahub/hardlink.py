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
