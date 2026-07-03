# MoviePilot V2 — design

Date: 2026-07-03
Host: `nixmachine` (media stack)

## Goal

Trial **MoviePilot V2** as a candidate **replacement for the entire *arr stack**.
Sonarr/Radarr search M-Team by IMDb ID (`imdbid=…`), and M-Team's Chinese-group
releases are mostly un-tagged, so targeted search returns almost nothing (see the
Yumi's Cells debugging). MoviePilot is built for the Chinese PT ecosystem +
Douban and does title/site-native search, so it should surface what \*arr can't.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deployment | OCI container via podman | Not in nixpkgs; podman already used (metatube) |
| Image pin | By digest (`@sha256:27919c55…`) | Reproducible; upstream ships rolling `latest` |
| Scope | **Full integration** | User intends to replace \*arr if it proves good; it manages the real `/tank/media` |
| Network | **LAN** — port 3000 in the nftables rule | It's a UI used daily |
| Secrets | **Root-only env file** (`/var/lib/moviepilot-secrets/env`) | recyclarr pattern; `API_TOKEN` out of the store |
| Identity | dedicated `moviepilot` user (uid 984) in `media` group | least-privilege; hardlinks via the group model |

## Runtime configuration (verified by test-run)

- Web UI is **nginx on :3000** (listens `0.0.0.0`); config in `/config`
  (`app.env`), honours **PUID/PGID/UMASK**.
- `PUID=984` (moviepilot), `PGID=991` (media), `UMASK=002` → imports are
  group-writable and **hardlink** within `/tank/media` (one ZFS dataset), same as
  the \*arr apps. The single `/tank/media` mount makes cross-boundary hardlinks work.
- `API_TOKEN` is required (from the env file). The **admin password is
  auto-generated on first boot and printed once** in the logs — no secret needed
  for it.
- First boot downloads a **~206MB CloakBrowser** (stealth Chromium for anti-bot
  scraping; useful against M-Team's Cloudflare). Slow first start; re-downloads
  if the container is recreated.
- A `bcrypt`/passlib version warning in the logs is harmless.

## Files

- `modules/nixos/media/moviepilot.nix` — user + container + tmpfiles (new)
- `modules/nixos/media/default.nix` — import `./moviepilot.nix` (edit)
- `modules/nixos/media/firewall.nix` — open TCP 3000 to the LAN (edit)

## Coexistence & migration (the trial → replace path)

- During the trial, MoviePilot and Sonarr/Radarr both see `/tank/media`. Hardlink
  permissions are safe, but **don't double-manage the same shows** in both tools.
- Configure **M-Team natively inside MoviePilot** (site cookies/API), not via
  Prowlarr, so the trial tests the standalone scenario.
- If MoviePilot proves good, a follow-up change removes `servarr.nix` +
  `recyclarr.nix` and their firewall/storage/dir entries. Evaluate coverage gaps
  first: subtitles (Bazarr → MoviePilot subtitle plugins), quality rules
  (Recyclarr/TRaSH → MoviePilot filter/priority rules).

## Runbook (post-deploy)

1. Create the secrets env file (the container won't start without it):
   ```
   sudo install -d -m 0700 /var/lib/moviepilot-secrets
   printf 'API_TOKEN=%s\n' "$(openssl rand -hex 16)" | sudo tee /var/lib/moviepilot-secrets/env >/dev/null
   sudo chmod 0600 /var/lib/moviepilot-secrets/env
   ```
2. `sudo nixos-rebuild switch --flake .#nixmachine` (first boot is slow — CloakBrowser download).
3. Grab the auto-generated admin password:
   `journalctl -u podman-moviepilot | grep 超级管理员`
4. Browse `http://<host>:3000`, log in as `admin`, change the password, then add
   M-Team, Transmission, Jellyfin, TMDB.

## Firewall caveat

Podman-published ports can bypass the nftables `input` chain, so the `3000` rule
is documentation + belt-and-suspenders; the real protection is the home NAT (no
public route to this host). For hard subnet enforcement, bind the port to the
LAN IP instead of `0.0.0.0`.

## Out of scope

agenix, isolated test paths (full integration chosen), plugin pre-config,
CloakBrowser cache persistence.
