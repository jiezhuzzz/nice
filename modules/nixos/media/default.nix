# Media automation stack for nixmachine. See
# docs/superpowers/specs/2026-07-01-media-automation-stack-design.md
{...}: {
  imports = [
    ./storage.nix
    ./jellyfin.nix
    ./metatube.nix
    ./firewall.nix
  ];
}
