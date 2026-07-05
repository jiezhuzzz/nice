"""Advisory classification via the Claude Code CLI. Claude returns JSON only;
it never touches the filesystem — the orchestration is the sole actor."""
from __future__ import annotations

import json
import re
import subprocess
from dataclasses import dataclass

_VALID_TYPES = ("movie", "tv", "anime")

PROMPT = """You are classifying a completed torrent for filing into a Jellyfin library.
Reply with ONLY a JSON object (no prose, no code fence) with exactly these keys:
  "type": one of "movie", "tv", "anime", or "unknown"
  "title": the English or romanized title (string)
  "year": integer release year, or null
  "season": integer season number, or null
  "episode": integer episode number, or null
  "confident": boolean — true only if you are sure of type and title

Torrent name: {name}
Files:
{files}
"""

# Defense in depth: even though the prompt asks for pure JSON, forbid every
# mutating tool so a misbehaving model still cannot alter the filesystem.
_DISALLOWED = "Write,Edit,MultiEdit,NotebookEdit,Bash,Task"


@dataclass
class AgentResult:
    type: str
    title: str | None
    year: int | None
    season: int | None
    episode: int | None
    confident: bool


def _default_runner(argv: list[str], timeout: int) -> str:
    proc = subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    return proc.stdout


def _extract_json(text: str) -> dict | None:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return None
    try:
        obj = json.loads(match.group(0))
    except json.JSONDecodeError:
        return None
    return obj if isinstance(obj, dict) else None


def _as_int(value) -> int | None:
    return value if isinstance(value, int) else None


def classify(name: str, files: list[str], *, runner=_default_runner, timeout: int = 120) -> AgentResult:
    prompt = PROMPT.format(name=name, files="\n".join(files))
    argv = ["claude", "-p", prompt, "--disallowedTools", _DISALLOWED]
    try:
        out = runner(argv, timeout)
    except (subprocess.SubprocessError, OSError):
        out = ""
    data = _extract_json(out) or {}
    ctype = data.get("type")
    confident = bool(data.get("confident")) and ctype in _VALID_TYPES and bool(data.get("title"))
    return AgentResult(
        type=ctype if ctype in _VALID_TYPES else "unknown",
        title=data.get("title") if isinstance(data.get("title"), str) else None,
        year=_as_int(data.get("year")),
        season=_as_int(data.get("season")),
        episode=_as_int(data.get("episode")),
        confident=confident,
    )
