# mediahub/filer.py
from __future__ import annotations
import os
import re
import subprocess

# NOTE: Claude Code's --allowedTools does prefix matching and cannot reliably enforce
# flags, so Bash(ln:*) technically permits `ln -s` / `ln -f`. This is the accepted
# soft-guard posture from the design (OS-level isolation was traded away by running the
# filer as the `transmission` user); the prompt below forbids any ln flags. Stronger
# enforcement (agent emits a link plan; hardlink.py does the collision-safe os.link) is
# a documented future option.
ALLOWED_TOOLS = "Read Bash(ls:*) Bash(stat:*) Bash(mkdir:*) Bash(ln:*)"
ALLOWED_TOOLS_DRY = "Read Bash(ls:*) Bash(stat:*)"  # no mkdir/ln — cannot change the fs
_RESULT = re.compile(r"^RESULT:\s*(linked|review)\b(.*)$", re.MULTILINE)
_KIND = re.compile(r"^KIND:\s*(.+)$", re.MULTILINE)
_DEST = re.compile(r"^DEST:\s*(.+)$", re.MULTILINE)


def _tools_for(env) -> str:
    return ALLOWED_TOOLS_DRY if env.get("DRY_RUN") else ALLOWED_TOOLS


def build_prompt(torrent_dir: str, media_root: str, dry_run: bool = False) -> str:
    if dry_run:
        action = (
            "For each media (video/audio) file, PRINT the exact `ln` command you WOULD run to "
            "hardlink it into the correct place, one per line. DO NOT execute anything — do not "
            "create dirs, do not link."
        )
    else:
        action = (
            "Hardlink each media (video/audio) file into the correct place with EXACTLY "
            "`ln <source> <dest>` — no flags. NEVER `ln -s` (symlink), NEVER `ln -f` "
            "(overwrites an existing file), and NEVER move or delete the source. Use "
            "`mkdir -p` to create destination directories first."
        )
    return f"""You are filing a finished torrent into a Jellyfin media library using HARDLINKS only.

Source directory: {torrent_dir}
Library root: {media_root}
Category subfolders: movies, tv, anime, xxx, music.
Naming:
- movies/<Title> (<Year>)/<file>
- tv/<Title>/Season <NN>/<file>
- anime/<Title>/<file>
- xxx/<CODE>/<file>          (CODE = the JAV code, e.g. JUX-455)
- music/<Artist>/<Album>/<file>

Rules:
- Inspect the files with ls/stat first.
- {action}
- Skip samples, .nfo, .rar, and other non-media files.
- If confident, end with EXACTLY one line: `RESULT: linked <count>`
- If you cannot confidently decide (ambiguous, mixed pack, unknown season), do NOT link.
  Output `KIND: <kind>` and `DEST: <path>` with your best guess if you have one, then
  end with EXACTLY one line: `RESULT: review <short reason>`
"""


def run_agent(prompt: str, cwd: str, env: dict) -> str:
    claude = env.get("CLAUDE_BIN", "claude")
    tools = _tools_for(env)
    proc = subprocess.run(
        [claude, "-p", prompt, "--allowedTools", tools],
        cwd=cwd, env=env, capture_output=True, text=True, timeout=600,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"claude exited {proc.returncode}: {proc.stderr[:500]}")
    return proc.stdout


def _enqueue(store, *args) -> None:
    try:
        store.add(*args)
    except Exception as e:  # a store failure must not crash the completion hook
        import sys
        print(f"mediahub-file: failed to enqueue review: {e}", file=sys.stderr)


def file_torrent(torrent_dir, name, torrent_hash, media_root, store, agent=run_agent, env=None) -> str:
    env = env if env is not None else os.environ.copy()
    prompt = build_prompt(torrent_dir, media_root, dry_run=bool(env.get("DRY_RUN")))
    try:
        out = agent(prompt, cwd=torrent_dir, env=env)
    except Exception as e:  # any agent failure -> review, never crash
        _enqueue(store, torrent_hash, name, str(torrent_dir), None, None, f"agent error: {e}")
        return "review"

    m = _RESULT.search(out or "")
    if not m:
        _enqueue(store, torrent_hash, name, str(torrent_dir), None, None, "no RESULT line from agent")
        return "review"
    if m.group(1) == "review":
        km, dm = _KIND.search(out), _DEST.search(out)
        _enqueue(
            store, torrent_hash, name, str(torrent_dir),
            km.group(1).strip() if km else None,
            dm.group(1).strip() if dm else None,
            (m.group(2).strip() or "agent requested review"),
        )
        return "review"
    return "linked"
