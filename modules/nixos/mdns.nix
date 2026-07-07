# mDNS / zeroconf via Avahi. Advertises this host's `networking.hostName` on the
# LAN as `<hostname>.local`, so services can link to each other by name instead of
# a DHCP-assigned IP (e.g. the Glance dashboard's links to the other web UIs), and
# lets this box resolve other `.local` names too. Reusable leaf: any host that
# wants `.local` discovery just imports this — no per-host config. Avahi manages
# its own firewall opening for the mDNS port (UDP 5353).
_: {
  services.avahi = {
    enable = true;
    nssmdns4 = true; # resolve other hosts' <name>.local from this machine
    publish = {
      enable = true;
      addresses = true; # advertise this host's A records as <hostname>.local
    };
    openFirewall = true; # UDP 5353
  };
}
