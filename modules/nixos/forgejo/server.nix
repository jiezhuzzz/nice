# Forgejo — self-hosted git forge (Forgejo LTS, sqlite, state under
# /var/lib/forgejo). Tailnet-only for the web UI, the vaultwarden/memos/shiori
# posture: binds 127.0.0.1 and opens no firewall port, so
# https://git.jiezhu.me through caddy is the only way in. Port 8081 sits just
# below the 8082-8087 service block — metatube holds 8080, and ad-hoc
# `dsh web` runs squat 8088 upward.
#
# Git over SSH uses Forgejo's own SSH server rather than the host's sshd. That
# keeps every git credential inside this unit: no forced-command entries in a
# system account's authorized_keys, and no login shell to reason about. It
# binds 0.0.0.0:2222 with no allowedTCPPorts entry, so tailscale0 — a trusted
# interface, see tailscale.nix — is the only way to reach it while LAN and WAN
# stay closed. Clone URLs read ssh://git@git.jiezhu.me:2222/jie/repo.git.
#
# Registration is off: this is a single-user forge, so the first account
# cannot come from the web UI. Create it once, after the first deploy:
#
#   sudo -u forgejo -H forgejo -c /var/lib/forgejo/custom/conf/app.ini \
#     admin user create --username jie --email jiezhu@uchicago.edu \
#     --admin --random-password
#
# then sign in with the printed password and change it. `-H` is there on
# purpose: forgejo aborts before doing anything if HOME is unset, and whether
# a plain `sudo -u` clears it is a sudoers policy detail — -H pins it to
# forgejo's own home either way.
#
# Nightly `forgejo dump` (04:31, upstream's default) onto the raidz2 tank pool,
# away from the rpool mirror holding the live database — the same split
# vaultwarden uses. Unlike vaultwarden's single overwritten copy this keeps a
# rolling window, pruned at two weeks rather than the module's four because
# every archive is a FULL copy of every repository.
{config, ...}: {
  services.forgejo = {
    enable = true;
    lfs.enable = true;

    dump = {
      enable = true;
      backupDir = "/tank/cache/backups/forgejo";
      type = "tar.zst"; # zip is the module default; git objects are already deflated
      age = "2w";
    };

    settings = {
      server = {
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = 8081;

        # Absolute public URL. Forgejo builds clone URLs, webhook origins and
        # the GITHUB_SERVER_URL handed to Actions jobs from this, so it must be
        # the caddy name rather than the loopback address it actually binds.
        # runner.nix reads DOMAIN back out to keep the two in step.
        DOMAIN = "git.jiezhu.me";
        ROOT_URL = "https://git.jiezhu.me/";

        START_SSH_SERVER = true;
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_LISTEN_PORT = 2222;
        SSH_PORT = 2222; # what clone URLs advertise; equal here, no port forwarding
        SSH_DOMAIN = "git.jiezhu.me";
        BUILTIN_SSH_SERVER_USER = "git";
        # Only the host's sshd would ever read that file, and it is not in the
        # path to a repository here.
        SSH_CREATE_AUTHORIZED_KEYS_FILE = false;
      };

      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;

      # The runner in ./runner.nix is the only executor this instance has.
      actions.ENABLED = true;
    };
  };

  # An explicit opt-out: catppuccin.autoEnable in lib/mk-hosts.nix would
  # otherwise theme the forge as soon as services.forgejo is on.
  catppuccin.forgejo.enable = false;

  # The admin CLI above, pinned to the exact build the unit runs: `forgejo
  # admin` and `forgejo doctor` write to the live database, and a version skew
  # between CLI and service is how migrations get applied twice. Free in disk
  # terms — the service already pulls this closure in.
  environment.systemPackages = [config.services.forgejo.package];
}
