# SearXNG — self-hosted metasearch engine, the search backend for pi's
# rpiv-web-tools `web_search` tool. One instance per LAN: it lives on
# nixmachine (the homelab box), reachable at searx.jiezhu.me over the tailnet
# (caddy.nix) and at http://nixmachine.local:8085 on the LAN. Binds 0.0.0.0
# with openFirewall, matching the other web UIs (glance.nix) — the box is
# NAT'd (v4) and ULA-only (v6), and the tailnet interface is trusted
# (tailscale.nix).
#
# search.formats MUST keep "json": rpiv-web-tools' searxng provider talks the
# JSON API and gets 403 if only html is enabled (searxng's default installs
# ship html-only). No Bearer proxy sits in front, so pi needs no key — just a
# base URL (SEARXNG_URL env var or baseUrls.searxng in
# ~/.config/rpiv-web-tools/config.json).
{config, ...}: {
  services.searx = {
    enable = true;
    openFirewall = true; # opens settings.server.port

    # secret_key is substituted from the agenix env file at activation time
    # (envsubst), so the value never lands in the Nix store.
    environmentFile = config.age.secrets.searxng-secret-key.path;

    settings = {
      server = {
        bind_address = "0.0.0.0";
        port = 8085;
        secret_key = "$SEARX_SECRET_KEY";
        # Trusted LAN/tailnet only — enable + redis if this box is ever
        # exposed beyond them (services.searx.redisCreateLocally).
        limiter = false;
      };
      search = {
        formats = ["html" "json"]; # "json" required by pi's searxng provider
        safe_search = 0; # don't filter what pi asks for
        default_lang = "all";
      };
      ui = {
        static_use_hash = true;
        default_locale = "en";
      };
      general.instance_name = "Homelab Search";
    };
  };

  # Only nixmachine runs searxng; password-manager is kept as the
  # editing/recovery recipient (same pattern as glance.nix's waqi-token).
  age.secrets.searxng-secret-key = {
    file = ../../secrets/searxng/secret-key.age;
    mode = "0400";
  };
}
