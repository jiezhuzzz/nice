# Media Filer — Agent-Assisted Hardlink-on-Completion (Design)

**Status:** approved · **Date:** 2026-07-05 · **Host:** nixmachine

## Problem

When Transmission finishes a download under `/tank/media/downloads`, the
release needs to be hardlinked into the Jellyfin library
(`/tank/media/{movies,tv,anime}`) with a clean, Jellyfin-standard name. A pure
regex/`guessit` parser handles most releases but fails on hard cases — CJK /
non-English titles (e.g. `基督山伯爵`), fansub naming, ambiguous anime-vs-TV.
For those, we want to consult a Claude Code agent.

A prior attempt ran the filer *inside* Transmission's `script-torrent-done`
hook. That failed: the hook inherits Transmission's `ProtectSystem=strict`
systemd sandbox, so the library and the agent's state dir were read-only. This
design decouples the work from the sandbox instead of loosening it.

## Non-goals

- No web UI, no review queue, no orchestrator (n8n/Windmill). Native + in-flake.
- Music and `xxx` are out of scope; they fall through to "leave unfiled + log."
- Claude never mutates the filesystem — it only advises (returns JSON).

## Architecture

```
torrent completes
  └─ transmission script-torrent-done hook  (in sandbox, as `transmission`)
       writes  /tank/media/downloads/.filer-queue/<hash>.job   (dump of TR_* env)
  └─ systemd.path (DirectoryNotEmpty) ── triggers ──▶ media-filer.service
       user media-filer · group media · RW on /tank/media · own HOME (StateDirectory)
       drains the queue; per job:
         1. load TR_* (DIR, NAME, HASH, LABELS)
         2. enumerate video files (skip samples/extras/nfo by name + size)
         3. guessit parse → {type,title,year,season,episode,confidence}
         4. if low-confidence & category in scope → claude -p (advisory JSON), merge
         5. confident & type ∈ {movie,tv,anime} → compute dest, hardlink
            else → log "unfiled: <name>, reason"
         6. delete the .job
```

**Why the spool bridge works with zero sandbox change:** the download-dir is
the one path Transmission's sandbox mounts read-write, so the hook *can* write
`.filer-queue/<hash>.job` there. `BindPaths` mount the real directory into the
namespace, so the job file lands on the real ZFS dataset and is visible to the
(unsandboxed) filer service. The hook does nothing else — it returns instantly,
so the agent never blocks a Transmission worker.

## Components

### NixOS module — `modules/nixos/media/filer.nix`

- `media-filer` system user (no login), member of group `media`.
- The packaged Python app (below) on the service PATH, plus `claude` (claude-code).
- The done-hook (`pkgs.writeShellScript`) that dumps `env | grep ^TR_` into the
  spool, wired via `services.transmission.settings`:
  `script-torrent-done-enabled = true;`
  `script-torrent-done-filename = "<hook>";`
  (The hook wiring lives here, in the feature module — `transmission.nix` stays
  a pure daemon config.)
- `systemd.tmpfiles` rule creating `/tank/media/downloads/.filer-queue`
  (`transmission:media 2775`) so both the hook (writer) and the filer (deleter,
  via group-write) can use it.
- `systemd.paths.media-filer` (`pathConfig.DirectoryNotEmpty = <queue>`) →
  `systemd.services.media-filer`.
- `systemd.services.media-filer`: `User=media-filer`, `Group=media`,
  `StateDirectory=media-filer` (→ `/var/lib/media-filer`, the agent's writable
  `$HOME`), `Environment=HOME=/var/lib/media-filer`,
  `EnvironmentFile=-/var/lib/media-filer/env` (root-only, holds
  `ANTHROPIC_API_KEY`), sandbox `ProtectSystem=strict` +
  `BindPaths=/tank/media`, **network allowed** (Claude needs egress).

### Python app — `buildPythonApplication` (guessit + stdlib)

Small, modular, TDD'd:

- `parse.py` — `guessit` wrapper → normalized candidate + a confidence signal.
  Re-applies edge cases learned in the earlier iteration (that code is gone):
  a `_scalar()` helper to collapse guessit lists (multi-year titles), an
  extended source regex (DVD/DVDRip), and an extended resolution regex
  (`WxH` / interlaced).
- `agent.py` — builds the prompt (torrent name + file listing), runs
  `claude -p` with read-only tools only, parses & validates the returned JSON.
- `layout.py` — Jellyfin destination path + a hard `is_relative_to("/tank/media")`
  clamp on every computed dest.
- `hardlink.py` — idempotent `os.link` (skip if same inode, refuse to overwrite
  a different inode).
- `filer.py` — orchestration: drain the queue, per-job flow, structured logging.
- `cli.py` — entrypoint (drain mode).
- `tests/` — see Testing.

## Naming conventions (Jellyfin-standard)

- **Movies** → `movies/<Title> (<Year>)/<Title> (<Year>).<ext>`.
- **TV** → `tv/<Show>/Season <NN>/<Show> - S<NN>E<MM>.<ext>`; season packs
  produce one hardlink per episode.
- **Anime** → `anime/<Title>/Season <NN>/<Title> - S<NN>E<MM>.<ext>` when a
  season is known; for absolute-numbered fansubs with no season,
  `anime/<Title>/<Title> - <NNN>.<ext>`. The agent decides which applies.

Only video files are linked. **Sidecar subtitle linking is a deferred
follow-up** — external `.srt`/`.ass` files stay in the download dir for now
(embedded subtitles play fine either way).

All links are within the single `tank/media` ZFS dataset (one copy on disk); the
original download is never touched and keeps seeding.

## Confidence & category selection

Deterministic-confident when: type ∈ {movie, episode}, title is non-empty and
ASCII-clean, and (movie has a year) / (episode has at least a season — the
episode *number* is resolved per-file, so season packs still qualify). Escalate
to Claude when: title is non-ASCII/CJK, type is missing, a movie lacks a year, or
an episode lacks a season.

**Label hint (wired now):** if `TR_TORRENT_LABELS` contains a known category
keyword (`movie`/`tv`/`anime`), it is a strong hint. When it is *compatible* with
guessit's structural type (`movie` label ↔ movie parse; `tv`/`anime` label ↔
episode parse) it selects/overrides the category; when it *conflicts* (e.g. a
`movie` label on a season pack) the release is escalated to Claude rather than
mis-filed. Free and reliable when the PT client sets labels; a no-op when it
doesn't.

Claude returns its own confidence. If Claude is also unsure → leave unfiled + log.

## Multi-file handling

A torrent's top-level item may be a single file or a directory containing:
one movie (+ subs), a season pack (many episodes), or junk (samples, `.nfo`,
screenshots). The filer enumerates by known video extension
(`mkv/mp4/avi/ts/m2ts/…`), drops obvious samples (name contains `sample`/`trailer`
or size below a threshold), and:
- **movie** → hardlink the largest video file as the feature (+ matching subs);
- **season pack** → parse and hardlink each episode file individually.

## Error handling · idempotency · observability

- Destination exists & same inode → skip (already filed). Exists & different
  inode → log a conflict and skip (never overwrite).
- Every destination is clamped inside `/tank/media`; the source is never
  modified (only `os.link`).
- A `.job` is deleted only after the item is handled (filed *or* logged-skip), so
  a crash leaves the job for retry — at-least-once delivery, made safe by
  idempotency.
- Per-job isolation: one bad torrent doesn't block the rest of the queue.
- All decisions log to journald (`journalctl -u media-filer`): hash, name,
  decision, destination, reason.

## Security

- `media-filer` is a dedicated no-login system user in group `media`; the
  service is sandboxed (`ProtectSystem=strict`, `BindPaths=/tank/media`,
  `StateDirectory`), with network egress allowed only because Claude needs it.
- `ANTHROPIC_API_KEY` lives in a root-only env file out of the Nix store.
- Claude runs in advisory mode with **no write tools** — the Python app is the
  sole thing that touches the filesystem and validates every destination. This
  removes the "autonomous agent with shell + library write" risk of the prior
  design.

## Extensibility: Claude Code skills

Because Claude runs with a stable, writable `$HOME` (`/var/lib/media-filer`),
skills can later be dropped into `~/.claude/skills/` and the filer's Claude will
pick them up with no rearchitecting — e.g. a TMDB-lookup skill or a
mediainfo-probe skill to sharpen the advisory decision. No filesystem-write
tools are granted regardless; skills extend *reasoning*, not authority.

## Testing (TDD)

- **Unit:** `parse` (movie / TV / anime / CJK / season-pack / sample fixtures),
  `layout` (Jellyfin paths + the `/tank/media` clamp), `hardlink` (idempotent /
  conflict / cross-link), `agent` (mocked Claude JSON: valid / low-confidence /
  malformed).
- **Integration:** drain a fabricated `.job` against a temp file tree; assert the
  expected hardlinks appear and skips are logged. The `claude` subprocess is
  stubbed.
- `nix flake check` / build the package.

## Deployment notes

- Add `./filer.nix` to `modules/nixos/media/default.nix`.
- Create `/var/lib/media-filer/env` (root, `0600`) with `ANTHROPIC_API_KEY=…`.
- `sudo nixos-rebuild switch --flake .#nixmachine` (run by the user via `!`).
