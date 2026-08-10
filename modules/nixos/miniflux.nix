# Miniflux — self-hosted RSS/Atom reader, postgres-backed. Tailnet-only: binds
# 127.0.0.1, no firewall port, caddy is the only way in. 8086 because metatube
# holds 8080. Login is skipped via the X-Auth-User header caddy sets
# (web-services.nix). Private-network fetching is on so rsshub.nix is
# subscribable, at the cost of miniflux's SSRF guard.
{config, ...}: {
  services.miniflux = {
    enable = true;
    adminCredentialsFile = config.age.secrets.miniflux-admin-credentials.path;

    config = {
      LISTEN_ADDR = "127.0.0.1:8086";
      BASE_URL = "https://miniflux.jiezhu.me";
      AUTH_PROXY_HEADER = "X-Auth-User";
      TRUSTED_REVERSE_PROXY_NETWORKS = "127.0.0.1/32";
      FETCHER_ALLOW_PRIVATE_NETWORKS = "1";
    };
  };

  age.secrets.miniflux-admin-credentials = {
    file = ../../secrets/miniflux/admin-credentials.age;
    mode = "0400";
  };
}
