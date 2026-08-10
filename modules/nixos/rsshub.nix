# RSSHub — generates feeds for sites that publish none; subscribe from
# miniflux.nix at http://127.0.0.1:1200/<route>, browse routes at
# https://rsshub.jiezhu.me. No firewall port: it has no auth and every route
# fetches an arbitrary upstream, so a LAN port would be a free fetch proxy.
{
  services.rsshub = {
    enable = true;
    settings.PORT = 1200;
  };
}
