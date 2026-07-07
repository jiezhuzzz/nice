# profiles/home/desktop.nix
# Home config for personal desktop machines (macOS and NixOS).
{
  imports = [
    ./core.nix
    ../../modules/home-manager/common/fish.nix
    ../../modules/home-manager/common/zed.nix
    ../../modules/home-manager/common/rime.nix
    ../../modules/home-manager/common/ghostty
    ../../modules/home-manager/common/ssh-identities.nix
  ];
}
