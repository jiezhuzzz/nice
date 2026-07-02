# Media automation stack for nixmachine. See
# docs/superpowers/specs/2026-07-01-media-automation-stack-design.md
{...}: {
  imports = [
    ./storage.nix
    ./servarr.nix
    ./jellyfin.nix
    ./recyclarr.nix
    ./firewall.nix
  ];
}
