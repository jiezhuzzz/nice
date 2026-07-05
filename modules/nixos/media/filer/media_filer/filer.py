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
    candidates = [root] if root.is_file() else sorted(root.rglob("*"))
    out = []
    for p in candidates:
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


def _compatible(label_cat: str | None, gtype: str | None) -> bool:
    """A category label is compatible with guessit's structural type when it
    does not contradict it: `movie` labels only fit movies; `tv`/`anime` labels
    only fit episodes. Incompatible pairs escalate to the agent instead of
    mis-filing."""
    if label_cat is None:
        return True
    if gtype == "movie":
        return label_cat == "movie"
    if gtype == "episode":
        return label_cat in ("tv", "anime")
    return False


def _resolve(name: str, files: list[Path], labels: str, classify) -> agent_mod.AgentResult | None:
    """Decide (category, title, year, season, episode). Returns an AgentResult-shaped
    decision, or None if we cannot confidently file it."""
    label_cat = _label_category(labels)
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
        if decision.year is None:
            log.info("unfiled: %s (movie without year)", name)
            return [Result("unfiled", str(src_root), None, "movie without year")]
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
    except OSError as e:
        # e.g. EPERM (protected_hardlinks on a non-group-writable source) or
        # EXDEV (dest on a different dataset). Log cleanly instead of crashing
        # the drain; the job is still consumed (a retry wouldn't help these).
        log.error("error: could not link %s -> %s: %s", src.name, dest, e)
        return Result("error", str(src), str(dest), str(e))
    log.info("%s: %s -> %s", action, src.name, dest)
    return Result(action, str(src), str(dest))
