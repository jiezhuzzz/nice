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
