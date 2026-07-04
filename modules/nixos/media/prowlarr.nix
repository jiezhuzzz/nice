# modules/nixos/media/prowlarr.nix
# Headless Prowlarr — the search engine aggregating HDSky / M-Team / OpenCD.
# Used ONLY as a search API + authenticated .torrent proxy by mediahub. The three
# indexers and their credentials are added once through the web UI (:9696, LAN)
# and live in Prowlarr's own state DB — not the Nix store. Prowlarr generates its
# API key on first run; copy it into /var/lib/mediahub-secrets/env (see mediahub.nix).
_: {
  services.prowlarr = {
    enable = true;
    openFirewall = false; # LAN rule is in firewall.nix
  };
}
