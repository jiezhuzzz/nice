# Media web UIs reachable only from the home LAN. `extraInputRules` is nftables
# syntax; nftables is already enabled on this host (for Transmission's 9091).
# extraInputRules is a merged `lines` option, so this concatenates with the
# host's existing 9091 rule rather than conflicting.
# Ports: jellyfin 8096.
_: {
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 8096 accept
  '';
}
