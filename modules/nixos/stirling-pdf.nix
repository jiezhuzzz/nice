# Stirling PDF — self-hosted PDF toolkit (merge/split/OCR/convert/sign, etc.).
# Native NixOS service (DynamicUser); the module bundles the full PDF toolchain
# (libreoffice, ocrmypdf, tesseract, ghostscript, qpdf, ...). Configured via env
# vars. Default port 8080 clashes with metatube, so use 8082. No login/secrets —
# a stateless tool; advanced-ops/Calibre left off to keep the closure lean.
_: {
  services.stirling-pdf = {
    enable = true;
    environment.SERVER_PORT = 8082;
  };

  # Upstream has no openFirewall option (the port is an opaque env var, so the
  # module can't know it); allowedTCPPorts is exactly what openFirewall would do.
  networking.firewall.allowedTCPPorts = [8082];
}
