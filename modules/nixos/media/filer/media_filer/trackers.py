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
