# mediahub/parse.py
from __future__ import annotations
import re
from dataclasses import dataclass, field

from guessit import guessit

_RES = [(re.compile(r, re.I), n) for r, n in [
    (r"2160p|\b4k\b|\buhd\b", "2160p"),
    (r"1080p", "1080p"),
    (r"720p", "720p"),
    (r"480p", "480p"),
]]
_SOURCE = [(re.compile(r, re.I), n) for r, n in [
    (r"remux", "Remux"),
    (r"web[-. ]?dl", "WEB-DL"),
    (r"web[-. ]?rip", "WEBRip"),
    (r"bd[-. ]?rip", "BDRip"),
    (r"blu[-. ]?ray|bdmv|\bbd\b", "BluRay"),
    (r"hdtv", "HDTV"),
    (r"hd[-. ]?rip", "HDRip"),
]]
_CODEC = [(re.compile(r, re.I), n) for r, n in [
    (r"h[.\- ]?265|x265|hevc", "H.265"),
    (r"h[.\- ]?264|x264|\bavc\b", "H.264"),
    (r"av1", "AV1"),
]]
_HDR = [(re.compile(r, re.I), n) for r, n in [
    (r"hdr10\+|hdr10|(?<![a-z])hdr(?![a-z])", "HDR"),
    (r"dolby[. ]?vision|dovi|(?<![a-z])dv(?![a-z])", "DV"),
]]
_AUDIO = [(re.compile(r, re.I), n) for r, n in [
    (r"atmos", "Atmos"),
    (r"true[-. ]?hd", "TrueHD"),
    (r"dts[-. ]?hd", "DTS-HD"),
    (r"(?<![a-z])dts(?![a-z])", "DTS"),
    (r"ddp|dd\+|e[-. ]?ac3", "DDP"),
    (r"(?<![a-z])ac3(?![a-z])|(?<![a-z])dd(?![a-z])", "DD"),
    (r"(?<![a-z])aac(?![a-z])", "AAC"),
    (r"flac", "FLAC"),
]]
# Trailing release group: "...-UBWEB" / "...-DIY@HDSWEB"
_GROUP_TAIL = re.compile(r"[-](?P<g>[A-Za-z0-9]+(?:@[A-Za-z0-9]+)?)\s*$")
_TECH_TOKENS = {"dl", "10bit", "8bit", "x264", "x265", "h264", "h265",
                "hevc", "avc", "hdr", "sdr", "dv"}


@dataclass
class Facets:
    title: str | None
    year: int | None
    kind: str | None            # guessit 'type': movie / episode / ...
    season: int | None
    resolution: str | None
    source: str | None
    codec: str | None
    hdr: list[str] = field(default_factory=list)
    audio: list[str] = field(default_factory=list)
    group: str | None = None


def _first(patterns, text):
    for rx, name in patterns:
        if rx.search(text):
            return name
    return None


def _all(patterns, text):
    out = []
    for rx, name in patterns:
        if rx.search(text) and name not in out:
            out.append(name)
    return out


def _scalar(v):
    """guessit yields a list when it finds multiple candidates for a field (e.g. two
    years in separate bracket groups); collapse to the first (or None if empty) so
    downstream scalar use — int(), .lower() — is safe."""
    if isinstance(v, list):
        return v[0] if v else None
    return v


def parse_release(title: str) -> Facets:
    g = guessit(title)
    season = _scalar(g.get("season"))
    year = _scalar(g.get("year"))
    group = _scalar(g.get("release_group"))
    if group and group.lower() in _TECH_TOKENS:
        group = None
    if group is None:
        m = _GROUP_TAIL.search(title)
        if m:
            cand = m.group("g")
            if len(cand) >= 4 and cand.lower() not in _TECH_TOKENS:
                group = cand
    return Facets(
        title=g.get("title"),
        year=int(year) if year else None,
        kind=g.get("type"),
        season=int(season) if season is not None else None,
        resolution=_first(_RES, title),
        source=_first(_SOURCE, title),
        codec=_first(_CODEC, title),
        hdr=_all(_HDR, title),
        audio=_all(_AUDIO, title),
        group=group,
    )
