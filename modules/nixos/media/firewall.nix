# Media web UIs reachable only from the home LAN. `extraInputRules` is nftables
# syntax, so we enable the nftables backend here — it regenerates all existing
# rules (SSH included) equivalently. extraInputRules is a merged `lines` option,
# so the rules below concatenate rather than conflict.
# Ports: transmission 9091, jellyfin 8096.
_: {
  networking.nftables.enable = true;
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 9091 accept
    ip saddr 192.168.86.0/24 tcp dport 8096 accept
  '';
}
