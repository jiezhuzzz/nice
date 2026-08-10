# The homelab's web UIs — plain data (the users/jie.nix pattern), imported by
# caddy.nix (one HTTPS vhost per entry) and glance.nix (one dashboard tile per
# entry with a `title`). One source of truth for each service's *.jiezhu.me
# name and localhost port, which used to be hand-repeated in both files.
#
# Adding a service here gives it the HTTPS name and the tile in one step. The
# port must still match what the service module itself binds — that setting
# keeps its own shape per service (PORT env, ROCKET_PORT, settings.server.port,
# …) and stays in the service's module.
#
# List, not attrset: the order is glance's tile order (and the vhost order in
# the generated Caddyfile, where it carries no meaning — the host matchers are
# disjoint).
[
  # The dashboard itself — a vhost but no tile of its own.
  {
    name = "glance";
    port = 8083;
  }
  {
    name = "jellyfin";
    port = 8096;
    title = "Jellyfin";
    icon = "di:jellyfin";
  }
  {
    name = "transmission";
    port = 9091;
    title = "Transmission";
    icon = "di:transmission";
  }
  {
    name = "pdf";
    port = 8082;
    title = "Stirling PDF";
    icon = "di:stirling-pdf";
  }
  {
    name = "karakeep";
    port = 8084;
    title = "Karakeep";
    icon = "di:karakeep";
  }
  {
    name = "searx";
    port = 8085;
    title = "SearXNG";
    icon = "di:searxng";
  }
  # Vaultwarden and Memos open no firewall port, so the caddy vhost generated
  # from these entries is their only reachable path — not merely a nicer name
  # for one, as with the services above.
  {
    name = "vault";
    port = 8222;
    title = "Vaultwarden";
    icon = "di:vaultwarden";
  }
  {
    name = "memos";
    port = 5230;
    title = "Memos";
    icon = "di:memos";
  }
]
