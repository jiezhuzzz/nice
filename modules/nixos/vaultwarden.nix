# Vaultwarden — self-hosted, Bitwarden-compatible password vault. Native NixOS
# service, sqlite backend, state under /var/lib/vaultwarden. No hardening added
# here: the upstream unit already ships strict systemd sandboxing.
#
# Exposure deliberately differs from the other web UIs on this box. It binds
# 127.0.0.1 and opens NO firewall port, so the only way in is
# https://vault.jiezhu.me through caddy over the tailnet — the litellm/metatube
# posture, not glance's any-source one. That costs nothing in practice:
# Bitwarden's apps and browser extensions refuse a non-HTTPS server, so a
# LAN-direct http://nixmachine.local:8222 would only ever have served a browser.
# Port 8222 is upstream's default and collides with nothing here.
#
# Signups stay off permanently; the first account is created from /admin, which
# ADMIN_TOKEN unlocks. That token is an Argon2 PHC hash (`vaultwarden hash`),
# not a plaintext password, and lives in agenix — see the secret at the bottom.
#
# Nightly sqlite backup (23:00, upstream's backup-vaultwarden.timer) onto the
# raidz2 tank pool, away from the rpool mirror holding the live database. Note
# what that does and does not buy: the script runs `sqlite3 .backup` and then
# overwrites the same destination every night, so it protects against a torn
# copy of a live database and against losing rpool — but it keeps no history.
# Until this host grows ZFS snapshots there is no way back to last week.
{config, ...}: {
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite"; # also required by backupDir (module assertion)
    backupDir = "/tank/cache/backups/vaultwarden";
    environmentFile = config.age.secrets.vaultwarden-admin-token.path;

    config = {
      # Absolute public URL. Vaultwarden builds invite/reset links and its
      # WebSocket origin check from this, so it must be the caddy name rather
      # than the loopback address it actually binds.
      DOMAIN = "https://vault.jiezhu.me";

      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      SIGNUPS_ALLOWED = false;
    };
  };

  # ADMIN_TOKEN for /admin, as an env file. Only nixmachine runs vaultwarden;
  # password-manager is the editing/recovery recipient (same pattern as
  # glance.nix's waqi-token).
  age.secrets.vaultwarden-admin-token = {
    file = ../../secrets/vaultwarden/admin-token.age;
    mode = "0400";
  };
}
