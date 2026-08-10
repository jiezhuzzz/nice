# Memos — self-hosted, lightweight note-taking service. Native NixOS service,
# sqlite backend, state under /var/lib/memos. No hardening added here: the
# upstream unit already ships a strict systemd sandbox (ProtectSystem=strict,
# an emptied CapabilityBoundingSet, a syscall filter).
#
# Tailnet-only, the vaultwarden posture rather than glance's any-source one: it
# binds 127.0.0.1 and opens no firewall port, so https://memos.jiezhu.me through
# caddy is the only way in. Here that is also the only posture the module can
# express — services.memos.openFirewall is broken upstream, its config branch
# reading a cfg.port option that does not exist, so setting it fails evaluation
# with "attribute 'port' missing". Port 5230 is memos' documented default (not
# the binary's own 8081 fallback) and collides with nothing else on this box.
#
# Signups cannot be turned off from here: disallowUserRegistration is a
# workspace setting living in the database, not an environment variable. The
# first account to register becomes the instance owner, so register immediately
# after the first deploy, then turn registration off in Settings → Workspace.
#
# Nothing backs this database up yet. Unlike vaultwarden the module ships no
# backup unit, so the sqlite file only ever exists on the rpool mirror.
{config, ...}: {
  services.memos = {
    enable = true;

    # Defining `settings` at all discards the module's default attrset — option
    # defaults are all-or-nothing, not merged per key — so every variable memos
    # needs is spelled out here. Upstream's default also carries MEMOS_MODE,
    # dropped deliberately: 0.29 has no --mode flag left for viper to bind that
    # name to, and the sqlite file is named memos_prod.db with or without it.
    settings = {
      MEMOS_ADDR = "127.0.0.1";
      MEMOS_PORT = "5230";
      MEMOS_DRIVER = "sqlite";
      # Track the option rather than repeating the path: it is what the module's
      # tmpfiles rule actually creates, and what the unit lists in ReadWritePaths.
      MEMOS_DATA = config.services.memos.dataDir;

      # Absolute public URL. Memos builds share links and webhook origins from
      # this, so it must be the caddy name rather than the loopback address it
      # actually binds.
      MEMOS_INSTANCE_URL = "https://memos.jiezhu.me";
    };
  };
}
