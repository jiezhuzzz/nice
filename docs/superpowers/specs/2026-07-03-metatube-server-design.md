# MetaTube metadata server — design

Date: 2026-07-03
Host: `nixmachine` (media stack)

## Goal

Provide accurate metadata (JAV + Western adult) for the Jellyfin library at
`/tank/media/xxx`. Jellyfin's built-in providers (TMDB/TVDB) have zero adult
coverage; the Jellyfin **MetaTube plugin** delegates to a MetaTube server, which
scrapes providers (JavBus, DMM/FANZA, etc.) and serves a REST API.

## Constraints / context

- `metatube-server` is **not packaged in nixpkgs**.
- `nixmachine` already runs **podman** (`hosts/nixos/nixmachine/default.nix`,
  `dockerCompat`, DNS) — so an OCI container is idiomatic and adds no packaging
  to maintain.
- Jellyfin runs on the **same host**, so the server needs no LAN exposure.
- Secrets use agenix; firewall is a LAN-restricted nftables dport list.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deployment | OCI container via `virtualisation.oci-containers` (podman) | Not in nixpkgs; podman already present |
| Image pin | By **digest** (`@sha256:04d5…`) | Reproducible rebuilds; upstream ships rolling `latest` |
| Database | **SQLite** at `/var/lib/metatube/metatube.db` | Single-user homelab; one file, trivial backup; no extra service |
| Network | Publish **`127.0.0.1:8080`** only | Jellyfin is co-located; no firewall change, not reachable off-host |
| Auth token | **None** for now | Not off-host reachable; can add `-token` (via agenix) later |

## Runtime configuration (verified by test-run)

Entrypoint `/metatube-server`, runs as **root**, exposes 8080. Working flags:

```
-bind 0.0.0.0 -port 8080 -dsn /config/metatube.db -db-auto-migrate
```

- `-bind 0.0.0.0` — binds all interfaces *inside* the container netns; the host
  publishes only to `127.0.0.1`, so it stays localhost-only.
- `-dsn /config/metatube.db` — bare path selects SQLite (no scheme → SQLite).
- `-db-auto-migrate` — required; GORM creates/updates the schema on boot
  (idempotent). Without it the persistent DB is not initialised.

Volume `/var/lib/metatube:/config` holds `metatube.db`; created via
`systemd.tmpfiles` (`0750 root root`).

Verified locally: container `Status=running RestartCount=0 OOMKilled=false`,
`GET /` → 200, `/v1/...` routes respond, `metatube.db` persists to the volume.

## Files

- `modules/nixos/media/metatube.nix` — the container + tmpfiles rule (new)
- `modules/nixos/media/default.nix` — import `./metatube.nix` (edit)

## Manual (UI, not Nix — same as other Jellyfin plugins)

1. Jellyfin → Dashboard → Plugins → Repositories → add the MetaTube plugin repo.
2. Catalog → install **MetaTube** → restart Jellyfin.
3. Configure the plugin's server URL to `http://localhost:8080` (no token).
4. On the `/tank/media/xxx` library, set MetaTube as the metadata provider.

## Out of scope (deferrable)

PostgreSQL backend, LAN exposure of the web UI, API token, image auto-updates.
