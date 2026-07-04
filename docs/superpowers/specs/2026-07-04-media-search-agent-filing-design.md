# Media Search + Agent Filing — Design

- **Date:** 2026-07-04
- **Host:** `nixmachine`
- **Status:** Design approved (brainstorming); pending implementation plan.

## 1. Goal

Replace the retired *arr / MoviePilot / IYUU stack with a lean workflow for the
two things actually needed:

1. **Aggregated, filterable search** across the user's private trackers
   (HDSky, M-Team, OpenCD), grabbing a chosen release **straight to
   Transmission** — server-side, no local download-then-reupload.
2. On download completion, an **agent (Claude Code, headless)** categorizes and
   **hardlinks** each release into the Jellyfin library by resource kind
   (movie / TV / anime / XXX / music). Ambiguous cases go to a **review queue**.

Non-goals for v1: subscription/RSS auto-grab, a heavyweight web app, push
notifications, and a hand-written deterministic categorizer (the agent *is* the
categorizer).

## 2. Requirements

**Functional**

- Search all three trackers from one place.
- Filter results by **quality** (resolution, source, codec, HDR, audio),
  **release group**, size, seeders, site, and category; sort by any of these.
- Grab a chosen release → added to Transmission directly.
- On completion, hardlink the media files into
  `/tank/media/{movies,tv,anime,music,xxx}` with Jellyfin-friendly names,
  decided by kind.
- Low-confidence / ambiguous releases → a review queue showing the agent's
  suggestion; the user places them with one action.

**Non-functional**

- Declarative NixOS; app source lives in-repo; reproducible build.
- Web surfaces reachable from the home LAN only; secrets kept out of the Nix
  store.
- **Seeds are never moved or deleted** — filing is hardlink-only, so the
  download copy keeps seeding (ratio-safe; the lesson from the earlier cleanup).
- Lean: reuse Prowlarr (search engine), Transmission (already deployed), and
  Claude Code (agent). Keep bespoke code small.

## 3. Key decisions (resolved during brainstorming)

- **Search engine — Prowlarr (headless), all three sites.** M-Team has an easy
  JSON API, but HDSky and OpenCD are NexusPHP sites behind Cloudflare; scraping
  them is a maintenance tax Prowlarr already absorbs (community-maintained
  indexer definitions, a Cloudflare solver, and an authenticated `.torrent`
  proxy). Running Prowlarr for all three is simpler than a hybrid.
- **Interface — a thin custom web app.** Prowlarr's native search UI can sort
  and pre-select categories/indexers, but it **cannot filter by quality or
  release group**, because those aren't structured fields — they live inside the
  release *title*. The app's core job is to parse titles into filterable facets.
- **Grab — the web app adds to Transmission via RPC** using Prowlarr's
  authenticated download URL (so the app never handles tracker cookies).
- **Filing — Claude Code (headless)** invoked on Transmission's
  `script-torrent-done` completion hook. Auto-hardlink when confident; review
  queue otherwise.
- **Filing trigger — the hook runs the filer directly as the `transmission`
  user** (chosen for leanness: no extra service endpoint, no `sudo`, no
  privilege plumbing). **Accepted trade-off:** the agent therefore runs as the
  user that *owns* the seeds, so Claude Code's `--allowedTools` whitelist is the
  **sole** guard against a destructive misfire — there is no OS-level isolation
  from the download data. This is acceptable because the whitelist admits only
  read/`ls`/`stat`/`mkdir`/`ln` — no `rm`, `mv`, or writes.
- **Orchestration — a plain completion-hook script. No n8n.** n8n is a
  heavyweight stateful service; for a single linear hook → agent → hardlink
  pipeline it is more infrastructure than a small script needs. (Revisit only if
  a general automation hub is wanted later.)
- **Agent — Claude Code (not Codex).** Already in use; its granular
  `--allowedTools` whitelist gives a clean hardlink-only safety scope.

## 4. Architecture

Two independent units that share only a SQLite review table:

```
browser ──LAN──▶ mediahub-web (FastAPI + htmx, :8083, user `mediahub`)
                   ├─ GET  /             search page (htmx)
                   ├─ GET  /api/search   Prowlarr search → parse titles → faceted, filterable table
                   ├─ POST /api/grab     fetch Prowlarr download URL → Transmission RPC add
                   ├─ GET  /review       pending items the agent punted (reads SQLite)
                   └─ POST /api/place    hardlink a reviewed item to a chosen destination

Prowlarr (headless, :9696)  ── search API + authenticated .torrent proxy
Transmission (existing, RPC :9091)
   └─ script-torrent-done ──exec──▶ file-download script  (runs AS `transmission`)
                                     └─ invoke Claude Code (headless) on the finished torrent dir
                                        → inspect files + existing library
                                        → hardlink+rename into /tank/media
                                        → uncertain? insert a row into the review queue

SQLite (/var/lib/mediahub/review.db, group `media`)  ── written by the filer, read by mediahub-web
```

- **mediahub-web** (user `mediahub`, in group `media`) — the search / grab /
  review UI. Talks to Prowlarr + Transmission over the network; reads the review
  queue; performs the hardlink for user-initiated `/api/place`.
- **file-download** (runs as `transmission`, invoked by the completion hook) —
  the agent filing. Because the hook already runs as `transmission`, no user
  switch is needed; the script simply execs Claude Code and hardlinks.

The two units communicate only through the review SQLite file, which lives in a
`media`-group-writable directory so both `transmission` and `mediahub` (both in
`media`) can access it.

## 5. Components

### 5.1 Prowlarr (reused; new NixOS module)

- **Purpose:** aggregate search across HDSky / M-Team / OpenCD; proxy `.torrent`
  downloads with each site's auth.
- **Interface:** REST — `GET /api/v1/search?query=&indexerIds=&categories=`
  with an `X-Api-Key` header; each result carries a Prowlarr-proxied
  `downloadUrl`.
- **Config:** the three indexers and their credentials are entered **once**
  through Prowlarr's web UI and stored in Prowlarr's own state DB — not in the
  Nix store. UI bound to the LAN on `:9696`.
- **Depends on:** network to the trackers; optionally FlareSolverr if HDSky /
  OpenCD present a Cloudflare challenge (add only if needed).

### 5.2 `mediahub-web` service (new; FastAPI + htmx)

Runs as the dedicated `mediahub` user (member of `media`). Internal modules,
each independently testable:

- `prowlarr.py` — `search(query, indexers, categories) -> [Release]`;
  `fetch_torrent(url) -> bytes`.
- `parse.py` — title → facets: resolution, source, codec, HDR, audio, **release
  group**, plus pass-through native fields (size, seeders, site, age, category).
  Uses `guessit` plus a CN-PT-aware release-group regex
  (`-GROUP`, `@GROUP`, `[GROUP]`).
- `transmission.py` — `add(torrent_bytes, download_dir) -> hash` via RPC.
- `hardlink.py` — `os.link` the whitelisted media files into a destination,
  idempotent, guards against `EXDEV` and collisions. Used by `/api/place`; the
  filer's own linking is done by the agent via `ln` (§5.3).
- `store.py` — SQLite DAO for the review queue.
- `web.py` — the routes below + htmx templates.

**Routes** (all LAN)

| Route | Purpose |
|-------|---------|
| `GET /` | Search page. |
| `GET /api/search?q=…&filters…` | Proxy Prowlarr, parse titles, return faceted + filtered + sorted results. |
| `POST /api/grab` `{downloadUrl,title}` | Fetch the `.torrent` via Prowlarr, add to Transmission (`download-dir=/tank/media/downloads`). Fire-and-forget. |
| `GET /review` | List pending review items with the agent's suggestion. |
| `POST /api/place` `{id,dest}` | Hardlink a reviewed item to a chosen destination; mark it done. Deterministic (given a dest — no agent). |

### 5.3 `file-download` filer (new; runs as `transmission`)

Shipped as a small script/module packaged with the app, invoked by the
completion hook.

1. Receives `TR_TORRENT_DIR` / `TR_TORRENT_NAME` / `TR_TORRENT_HASH` from
   Transmission.
2. Builds a prompt: the torrent directory path, the `/tank/media` layout and
   naming conventions (below), and strict instructions — **hardlink only**
   (`ln`, never `-s`, never move/delete the source), Jellyfin-friendly names,
   and end with a machine-readable `RESULT:` line (`linked` + what was linked,
   or `review` + a reason).
3. Invokes:
   `claude -p "<prompt>" --allowedTools "Read Bash(ls:*) Bash(stat:*) Bash(mkdir:*) Bash(ln:*)"`
   with `ANTHROPIC_API_KEY` from a root-owned env file readable by
   `transmission`, and `HOME` inside Transmission's state dir (for Claude's
   config). In headless (`-p`) mode `--allowedTools` is the allowlist: any tool
   not listed (e.g. `Bash(rm:*)`, `Bash(mv:*)`, `Write`) is denied
   automatically, with no interactive prompt.
4. Parses the `RESULT:` line: `linked` → log and finish; `review` (or any agent
   error / timeout / non-zero exit) → insert a row into the review queue. The
   pipeline never crashes and never blocks completion.

**Naming conventions (best-effort, Jellyfin-friendly)**

- `movies/<Title> (<Year>)/…`
- `tv/<Title>/Season <NN>/…` (unknown season → review)
- `anime/<Title>/…` (flat; anime scanners are lenient)
- `xxx/<CODE>/…` (JAV code extracted; MetaTube scrapes by code)
- `music/<Artist>/<Album>/…`

Only whitelisted media extensions are linked (video/audio); `.rar`, `.nfo`,
samples, and the like are skipped.

**Dry-run mode** (env flag): the agent is asked to print the `ln` commands it
*would* run without executing them (or `ln` is omitted from `--allowedTools`).
Used for safe first runs and tests.

### 5.4 Review store (SQLite)

Single table `review(id, hash, name, src_dir, suggested_kind, suggested_dest,
reason, created_at, status)` at `/var/lib/mediahub/review.db`. Written by the
filer (as `transmission`), read/updated by mediahub-web (as `mediahub`); the DB
directory is `2775` group `media` so both can access it.

### 5.5 Transmission hook (config change to existing service)

Set `settings.script-torrent-done-enabled = true` and
`settings.script-torrent-done-filename` to the `file-download` script. It runs
within `transmission.service`, so the service sandbox must permit it (see §8).

## 6. Data flow

1. **Search:** browser → `/api/search` → Prowlarr (all three indexers) →
   `parse.py` augments each result with facets → filtered/sorted table.
2. **Grab:** click → `/api/grab` → fetch Prowlarr download URL → Transmission
   RPC add into `/tank/media/downloads`.
3. **Complete:** Transmission finishes → hook execs `file-download` (as
   `transmission`) → Claude Code → hardlink into the library **or** enqueue for
   review.
4. **Review:** browser → `/review` → shows pending + suggestion → `/api/place`
   hardlinks to the chosen destination.

The download copy is never touched, so it keeps seeding throughout.

## 7. Storage & permission model

Single ZFS dataset `/tank/media` (hardlinks are one copy on disk; imports are
atomic). Library roots `movies/tv/anime/music/xxx` are `2775 root:media`
(setgid → new entries inherit group `media`). `downloads` stays
`2775 transmission:media`.

**Safety model (given filing runs as `transmission`):**

- The filer runs as `transmission`, which owns the downloads — so there is **no
  OS-level barrier** between the agent and the seed data. The **sole** guard is
  Claude Code's `--allowedTools` whitelist, which admits only
  `Read` + `ls` + `stat` + `mkdir` + `ln` — no `rm`, `mv`, or write commands.
  The prompt additionally forbids touching the source.
- Hardlinking into the library works because `transmission` is a member of
  `media` and the library roots are group-writable (`2775`), and files created
  inside inherit group `media` via setgid.
- `mediahub` (the web user) is also in `media`; for `/api/place` it hardlinks
  from `downloads` into the library. `fs.protected_hardlinks` permits this
  because the download files are group-`rw` (`0664`).

> Note: this is a deliberate simplicity/safety trade accepted during design. If
> stronger isolation is ever wanted, move filing to a dedicated non-owning user
> (via a localhost service endpoint or a `sudo` rule) — see the design history.

## 8. NixOS deployment

- `modules/nixos/media/prowlarr.nix` — `services.prowlarr`; LAN UI on `:9696`
  (needed once to add the three indexers); Prowlarr's API key exposed to
  `mediahub-web` via a **root-only env file** (out of the Nix store).
- `modules/nixos/media/mediahub.nix` — packages the app (source in-repo, Python
  via `uv`); systemd service `mediahub-web` as `User=mediahub` (group `media`),
  umask `002`, `ReadWritePaths=/tank/media /var/lib/mediahub`, binds
  `127.0.0.1:8083`, `EnvironmentFile` supplying `PROWLARR_API_KEY`; tmpfiles for
  `/var/lib/mediahub` (dir `2775` group `media`); nftables LAN rule for `:8083`.
  Also installs the `file-download` script.
- Edit `hosts/nixos/nixmachine/default.nix` (Transmission):
  - add `script-torrent-done-enabled` + `script-torrent-done-filename`;
  - give the `transmission` service the filer's needs by **widening its
    sandbox**: append the library roots and the agent's `HOME`/config dir to
    `systemd.services.transmission.serviceConfig.ReadWritePaths`, and ensure the
    service can exec `claude` and reach the Anthropic API (Transmission already
    has network egress). Provide `ANTHROPIC_API_KEY` via a root-owned env file
    readable by `transmission` (an `EnvironmentFile` on the service, or the
    script sources it).
- Firewall LAN rule adds **8083** (mediahub-web) and **9696** (Prowlarr setup).
- Import the two new modules from `modules/nixos/media/default.nix`.

Secrets summary: tracker credentials live in Prowlarr's state DB; the Prowlarr
API key and `ANTHROPIC_API_KEY` live in root-owned env files; nothing sensitive
enters the Nix store.

## 9. Error handling & edge cases

- **Prowlarr / Transmission down:** surfaced in the UI on search/grab.
- **Agent (Claude Code) error / timeout / unsure:** route to the review queue —
  never block completion, never guess.
- **Hardlink `EXDEV` or name collision:** review with a clear reason (never
  silently copy or overwrite).
- **Hook re-invocation for the same torrent:** idempotent — already-linked files
  are skipped (no duplicate links).
- **Transmission sandbox blocks the agent:** caught during deployment — the
  filer logs a clear error and the item lands in review (see §8 for the
  `ReadWritePaths` widening that prevents this).

## 10. Testing strategy

- `parse.py` — table of real releases → expected facets, seeded with the user's
  actual titles (`Project Hail Mary 2026 2160p WEB-DL … HDR DV-HDSWEB`,
  `[2023][Bleach Sennen Kessen Hen S2] … BDRIP 1080P`, `JUX-455`,
  `Yumi's Cells 2022 S02 … WEB-DL … -UBWEB`), plus `guessit` edge cases.
- `hardlink.py` — temp files: assert `st_nlink == 2`, idempotency, `EXDEV`
  fallback, collision handling.
- `prowlarr.py` / `transmission.py` — mocked HTTP / RPC.
- `file-download` filer — mocked Claude Code: `linked` path, `review` path,
  error → review path; `RESULT:` parsing.
- Web routes — FastAPI `TestClient`, happy + error paths.
- **Agent dry-run** end-to-end: log the `ln`s the agent would perform without
  executing, for a safe first real run.

## 11. Out of scope / future (YAGNI)

- Push notifications for the review queue — v1 shows a pending-count badge and
  logs; add ntfy/Telegram later if wanted.
- A deterministic categorizer fast-path — the agent is the categorizer; add a
  `guessit`-based shortcut only if per-download agent cost/latency becomes a
  problem.
- Subscriptions / RSS auto-grab — this workflow is user-driven by design.
- FlareSolverr — add only if HDSky / OpenCD actually challenge Prowlarr.
- Stronger filer isolation (non-owning user) — deferred; the `--allowedTools`
  whitelist is the accepted v1 guard.
