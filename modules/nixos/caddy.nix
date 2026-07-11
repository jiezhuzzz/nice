# Caddy — HTTPS front door for the web UIs, reachable only over the tailnet
# (:443 is admitted via the trusted tailscale0 interface; see tailscale.nix —
# no LAN or WAN rule opens it). Serves *.jiezhu.me with a single wildcard
# Let's Encrypt cert via the ACME DNS-01 challenge against Cloudflare: no
# inbound port is ever opened to the internet, and one wildcard cert keeps
# the service names out of public Certificate Transparency logs. The public
# *.jiezhu.me A record points at nixmachine's tailnet IP (DNS-only / grey
# cloud in Cloudflare — the edge can't reach a 100.x address).
#
# The scoped API token (Zone → DNS → Edit, jiezhu.me only) is an agenix
# secret (secrets/caddy/cloudflare-token.age → CLOUDFLARE_API_TOKEN), fed in
# via the module's environmentFile and referenced in the tls directive.
{
  config,
  pkgs,
  ...
}: {
  services.caddy = {
    enable = true;
    # Stock caddy can't do Cloudflare DNS-01; withPlugins rebuilds it with the
    # caddy-dns module baked in. To bump the plugin: set hash = lib.fakeHash,
    # rebuild, and copy the real hash from the mismatch error.
    package = pkgs.caddy.withPlugins {
      plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
      hash = "sha256-hEHgAG0F0ozHRAPuxEqLyTATBrE+pajeXDiSNwniorg=";
    };
    environmentFile = config.age.secrets.cloudflare-token.path;

    virtualHosts."*.jiezhu.me".extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        resolvers 1.1.1.1
      }

      @glance host glance.jiezhu.me
      handle @glance {
        reverse_proxy 127.0.0.1:8083
      }

      @jellyfin host jellyfin.jiezhu.me
      handle @jellyfin {
        reverse_proxy 127.0.0.1:8096
      }

      @karakeep host karakeep.jiezhu.me
      handle @karakeep {
        reverse_proxy 127.0.0.1:8084
      }

      @chat host chat.jiezhu.me
      handle @chat {
        reverse_proxy 127.0.0.1:8081
      }

      @pdf host pdf.jiezhu.me
      handle @pdf {
        reverse_proxy 127.0.0.1:8082
      }

      @transmission host transmission.jiezhu.me
      handle @transmission {
        reverse_proxy 127.0.0.1:9091
      }

      # Unmatched subdomain: close the connection, don't serve a default page.
      handle {
        abort
      }
    '';
  };

  # Cloudflare token as an env file (CLOUDFLARE_API_TOKEN=...). Scoped here
  # rather than in secrets/definitions.nix for the same reason as glance's
  # waqi-token: that mapper targets the desktop/darwin hosts, and nixmachine
  # is not one of its recipients.
  age.secrets.cloudflare-token = {
    file = ../../secrets/caddy/cloudflare-token.age;
    mode = "0400";
  };
}
