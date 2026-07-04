# Stirling PDF — self-hosted PDF toolkit (merge/split/OCR/convert/sign, etc.).
# Native NixOS service (DynamicUser); the module bundles the full PDF toolchain
# (libreoffice, ocrmypdf, tesseract, ghostscript, qpdf, ...). Configured via env
# vars. Default port 8080 clashes with metatube, so use 8082; it binds 0.0.0.0,
# so the nftables input rule restricts it to the home LAN. No login/secrets — a
# stateless LAN tool; advanced-ops/Calibre left off to keep the closure lean.
_: {
  services.stirling-pdf = {
    enable = true;
    environment.SERVER_PORT = 8082;
  };

  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 8082 accept
  '';
}
