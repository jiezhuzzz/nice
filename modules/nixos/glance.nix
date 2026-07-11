# Glance — lightweight self-hosted dashboard for the homelab. A single "glanceable"
# landing page: news feeds (Hacker News, Lobsters, RSS) plus a monitor
# widget that health-checks and links to the other web UIs on this box by their
# mDNS names (nixmachine.local — see ./mdns.nix) rather than a DHCP-assigned IP.
# Native NixOS service; binds 0.0.0.0 with openFirewall (any-source — the box
# is NAT'd (v4) and ULA-only (v6) and the tailnet interface is trusted), matching the other web UIs.
# Reachable at http://nixmachine.local:8083. Feeds and links are plain data —
# edit freely.
#
# The air-quality widget (custom-api) hits the WAQI API; its free token is an
# agenix secret (secrets/glance/waqi-token.age → WAQI_TOKEN), fed to the service
# via EnvironmentFile and referenced as ${WAQI_TOKEN} in the widget URL.
{config, ...}: {
  services.glance = {
    enable = true;
    openFirewall = true;
    # WAQI_TOKEN for the air-quality widget, via the module's EnvironmentFile.
    environmentFile = config.age.secrets.waqi-token.path;
    settings = {
      server = {
        host = "0.0.0.0";
        port = 8083;
      };

      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "weather";
                  location = "Chicago, Illinois, United States";
                  units = "metric";
                  "hour-format" = "24h";
                }
                {
                  # Air quality via the WAQI API (community custom-api widget:
                  # github.com/glanceapp/community-widgets .../air-quality).
                  # geo: coords are Chicago, matching the weather widget above.
                  type = "custom-api";
                  title = "Air Quality";
                  cache = "10m";
                  url = "https://api.waqi.info/feed/geo:41.8781;-87.6298/?token=\${WAQI_TOKEN}";
                  template = ''
                    {{ $aqi := printf "%03s" (.JSON.String "data.aqi") }}
                    {{ $aqiraw := .JSON.String "data.aqi" }}
                    {{ $updated := .JSON.String "data.time.iso" }}
                    {{ $humidity := .JSON.String "data.iaqi.h.v" }}
                    {{ $ozone := .JSON.String "data.iaqi.o3.v" }}
                    {{ $pm25 := .JSON.String "data.iaqi.pm25.v" }}
                    {{ $pressure := .JSON.String "data.iaqi.p.v" }}
                    <div class="flex justify-between">
                      <div class="size-h5">
                        {{ if le $aqi "050" }}
                          <div class="color-positive">Good air quality</div>
                        {{ else if le $aqi "100" }}
                          <div class="color-primary">Moderate air quality</div>
                        {{ else }}
                          <div class="color-negative">Bad air quality</div>
                        {{ end }}
                      </div>
                    </div>
                    <div class="color-highlight size-h2">AQI: {{ $aqiraw }}</div>
                    <div style="border-bottom: 1px solid; margin-block: 10px;"></div>
                    <div class="margin-block-2">
                      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                        <div>
                          <div class="size-h3 color-highlight">{{ $humidity }}%</div>
                          <div class="size-h6">HUMIDITY</div>
                        </div>
                        <div>
                          <div class="size-h3 color-highlight">{{ $ozone }} μg/m³</div>
                          <div class="size-h6">OZONE</div>
                        </div>
                        <div>
                          <div class="size-h3 color-highlight">{{ $pm25 }} μg/m³</div>
                          <div class="size-h6">PM2.5</div>
                        </div>
                        <div>
                          <div class="size-h3 color-highlight">{{ $pressure }} hPa</div>
                          <div class="size-h6">PRESSURE</div>
                        </div>
                      </div>
                      <div class="size-h6" style="margin-top: 10px;">Last Updated at {{ slice $updated 11 16 }}</div>
                    </div>
                  '';
                }
              ];
            }
            {
              size = "full";
              widgets = [
                {type = "hacker-news";}
                {type = "lobsters";}
                {
                  type = "rss";
                  title = "Tech News";
                  style = "detailed-list";
                  limit = 15;
                  "collapse-after" = 5;
                  feeds = [
                    {
                      url = "https://arstechnica.com/feed/";
                      title = "Ars Technica";
                    }
                    {
                      url = "https://www.theverge.com/rss/index.xml";
                      title = "The Verge";
                    }
                    {
                      url = "https://simonwillison.net/atom/everything/";
                      title = "Simon Willison";
                    }
                    {
                      url = "https://newsletter.pragmaticengineer.com/feed";
                      title = "Pragmatic Engineer";
                    }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "monitor";
                  title = "Services";
                  cache = "1m";
                  sites = [
                    {
                      title = "Jellyfin";
                      url = "http://nixmachine.local:8096";
                      icon = "di:jellyfin";
                    }
                    {
                      title = "Transmission";
                      url = "http://nixmachine.local:9091";
                      icon = "di:transmission";
                    }
                    {
                      title = "Open WebUI";
                      url = "http://nixmachine.local:8081";
                      icon = "di:open-webui";
                    }
                    {
                      title = "Stirling PDF";
                      url = "http://nixmachine.local:8082";
                      icon = "di:stirling-pdf";
                    }
                    {
                      title = "Karakeep";
                      url = "http://nixmachine.local:8084";
                      icon = "di:karakeep";
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
  };

  # WAQI token for the air-quality widget. Decrypts to /run/agenix/waqi-token as
  # an env file (WAQI_TOKEN=...); consumed via services.glance.environmentFile
  # above, which systemd (root) reads when preparing the unit. Scoped here rather
  # than in secrets/definitions.nix because that mapper targets the desktop/darwin
  # hosts, and nixmachine (the only glance host) is not one of its recipients.
  age.secrets.waqi-token = {
    file = ../../secrets/glance/waqi-token.age;
    mode = "0400";
  };
}
