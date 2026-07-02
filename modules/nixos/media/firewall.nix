# Media web UIs reachable only from the home LAN. `extraInputRules` is nftables
# syntax; nftables is already enabled on this host (for Transmission's 9091).
# extraInputRules is a merged `lines` option, so this concatenates with the
# host's existing 9091 rule rather than conflicting.
# Ports: prowlarr 9696 · radarr 7878 · sonarr 8989 · lidarr 8686 ·
#        whisparr 6969 · bazarr 6767 · jellyfin 8096.
_: {
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport { 9696, 7878, 8989, 8686, 6969, 6767, 8096 } accept
  '';
}
