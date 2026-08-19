# The homelab's web UIs — plain data imported by caddy.nix (one HTTPS vhost
# per entry) and glance.nix (one dashboard tile per entry with a `title`).
# Adding a service here gives it both in one step. The port must still match
# what the service module itself binds. List order is glance's tile order.
# An entry may also carry `proxyDirectives`: extra lines for its reverse_proxy block.
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
    name = "searx";
    port = 8085;
    title = "SearXNG";
    icon = "di:searxng";
  }
  # The rest open no firewall port — their caddy vhost is their only reachable
  # path, not merely a nicer name for one.
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
  {
    name = "shiori";
    port = 8084;
    title = "Shiori";
    icon = "di:shiori";
    # Passwordless login (SSO proxy auth in shiori.nix). No +/- prefix means
    # *set*, so a client's own Remote-User is replaced, not appended.
    proxyDirectives = "header_up Remote-User jie";
  }
  {
    name = "miniflux";
    port = 8086;
    title = "Miniflux";
    icon = "di:miniflux";
    # Passwordless login (AUTH_PROXY_HEADER in miniflux.nix). No +/- prefix
    # means *set*, so a client's own X-Auth-User is replaced, not appended.
    proxyDirectives = "header_up X-Auth-User jie";
  }
  {
    # dashboard-icons has no SVG for this one, and glance defaults to .svg.
    name = "rsshub";
    port = 1200;
    title = "RSSHub";
    icon = "di:rsshub.png";
  }
  {
    # No icon library carries a one-user project, so point glance straight at
    # the repo's own logo (served as image/svg+xml, so an <img> renders it).
    name = "xuewen";
    port = 8087;
    title = "Xuewen";
    icon = "https://raw.githubusercontent.com/jiezhuzzz/xuewen/main/assets/logo.svg";
  }
  {
    # Served by a systemd user unit (modules/home-manager/linux/dsh.nix), which
    # also passes this name to dsh as --trusted-host — rename both together.
    name = "dsh";
    port = 3080;
    title = "dsh";
    icon = "di:deepseek";
  }
]
