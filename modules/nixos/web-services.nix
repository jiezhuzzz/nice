# The homelab's web UIs — plain data imported by caddy.nix (one HTTPS vhost
# per entry) and glance.nix (one dashboard tile per entry with a `title`).
# Adding a service here gives it both in one step. The port must still match
# what the service module itself binds. List order is glance's tile order.
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
  # Vaultwarden and Memos open no firewall port — their caddy vhost is their
  # only reachable path, not merely a nicer name for one.
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
