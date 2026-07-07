"""Deterministic per-tracker parsing. Private trackers use rigid naming
conventions, so a small tracker-specific regex resolves releases that guessit
mis-parses (CJK titles, @group), skipping the Claude agent."""
from __future__ import annotations

import re
from urllib.parse import urlparse

from .parse import Candidate

# hostname substring -> tracker id. A substring match tolerates announce
# subdomains (pt.hdsky.me, tracker.hdsky.me, ...). Domains are not secrets.
_HOSTS: dict[str, str] = {"hdsky": "hdsky"}

_YEAR = r"(?:19|20)\d{2}"


def _clean(title: str) -> str:
    return title.replace(".", " ").strip()


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


class HDSky:
    # Anchored on landmarks; the qualities blob between landmark and @group is
    # ignored. Leading [^.]+ is the single CJK title token.
    _MOVIE = re.compile(rf"^[^.]+\.(?P<title>.+)\.(?P<year>{_YEAR})(?:\.|@)")
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
