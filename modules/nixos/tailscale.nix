# Tailscale — WireGuard mesh VPN connecting all personal machines; how
# nixmachine is reached from outside the home LAN (SSH + the web UIs fronted
# by caddy.nix). Trusting tailscale0 opens every local service to tailnet
# peers — safe because the tailnet contains only jie's logged-in devices.
# openFirewall admits the WireGuard UDP port so peers connect directly
# instead of relaying through DERP.
#
# Enrollment is deliberately imperative, once per machine: `sudo tailscale up`
# and follow the login URL. For servers (nixmachine), afterwards disable key
# expiry in the admin console so the node never silently drops off.
_: {
  services.tailscale = {
    enable = true;
    openFirewall = true;
  };
  networking.firewall.trustedInterfaces = ["tailscale0"];
}
