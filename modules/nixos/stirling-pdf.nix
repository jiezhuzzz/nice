# Stirling PDF — self-hosted PDF toolkit (merge/split/OCR/convert/sign, etc.).
# Native NixOS service (DynamicUser); the module bundles the full PDF toolchain
# (libreoffice, ocrmypdf, tesseract, ghostscript, qpdf, ...). Configured via env
# vars. Default port 8080 clashes with metatube, so use 8082. Stateless tool;
# advanced-ops/Calibre left off to keep the closure lean.
#
# v2 ships with security.enableLogin=true by default (login/account subsystem is
# compiled in), so we disable it via SECURITY_ENABLELOGIN — single-user tool
# behind the firewall/tailnet, no auth needed.
_: {
  # Upstream's committed test-signing certs (app/core/src/test/resources/certs)
  # expired 2026-08-26, so the 15 signature tests in the gradle check phase fail
  # on every rebuild from that date on. Drop this once nixpkgs carries a release
  # with regenerated fixtures.
  nixpkgs.overlays = [
    (_: prev: {
      stirling-pdf = prev.stirling-pdf.overrideAttrs (_: {
        doCheck = false;
      });
    })
  ];

  services.stirling-pdf = {
    enable = true;
    environment = {
      SERVER_PORT = 8082;
      SECURITY_ENABLELOGIN = "false";
    };
  };

  # Upstream has no openFirewall option (the port is an opaque env var, so the
  # module can't know it); allowedTCPPorts is exactly what openFirewall would do.
  networking.firewall.allowedTCPPorts = [8082];
}
