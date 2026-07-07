# Glance — lightweight self-hosted dashboard for the homelab. A single "glanceable"
# landing page: news feeds (Hacker News, Reddit, Lobsters, RSS) plus a monitor
# widget that health-checks and links to the other web UIs on this box by their
# mDNS names (nixmachine.local — see ./mdns.nix) rather than a DHCP-assigned IP.
# Native NixOS service; binds 0.0.0.0, so the nftables input rule restricts it to
# the home LAN, matching the other media/LLM UIs. Reachable at
# http://nixmachine.local:8083. Feeds and links are plain data — edit freely.
_: {
  services.glance = {
    enable = true;
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
                  type = "clock";
                  "hour-format" = "12h";
                }
                {
                  type = "weather";
                  location = "Chicago, Illinois, United States";
                  units = "imperial";
                  "hour-format" = "12h";
                }
              ];
            }
            {
              size = "full";
              widgets = [
                {type = "hacker-news";}
                {
                  type = "reddit";
                  subreddit = "programming+selfhosted";
                }
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
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
  };

  # LAN-only, following the same nftables pattern as the other web UIs on this box.
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 8083 accept
  '';
}
