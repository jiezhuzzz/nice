# profiles/nixos-desktop.nix
# Shared NixOS profile for desktop/laptop machines.
{
  inputs,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../modules/nixos/boot.nix
    ../modules/nixos/hardware
    ../modules/nixos/desktop
    ../modules/nixos/secrets.nix
    ../modules/nixos/tailscale.nix
  ];

  programs.fish.enable = true;

  # Binary cache for noctalia-shell (imported into home-manager below), whose
  # Quickshell/Qt closure is expensive to build from source.
  #
  # Deliberately set here rather than as `nixConfig` in flake.nix: that
  # attribute is honoured only for a trusted user, and `trusted-users` is just
  # `root`, so it would apply under `sudo nixos-rebuild switch` but be silently
  # ignored for an unprivileged `nix build` — falling back to a source build.
  # Baking it into the system's nix.conf applies it regardless of invoker.
  nix.settings = {
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    jq
    wget
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  networking.networkmanager.enable = true;

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  home-manager.users.${user.me.username} = {pkgs, ...}: {
    imports = [
      ./home/desktop.nix
      ../modules/home-manager/linux/packages.nix
      ../modules/home-manager/linux/niri.nix
      ../modules/home-manager/linux/noctalia.nix
      ../modules/home-manager/linux/chromium.nix
      ../modules/home-manager/linux/fcitx5.nix
      ../modules/home-manager/linux/ghostty.nix
      ../modules/home-manager/linux/shpool.nix
      ../modules/home-manager/linux/swaylock.nix
      ../modules/home-manager/linux/zathura.nix
    ];

    home.pointerCursor = {
      # Explicit since home-manager deprecated inferring this from the
      # presence of the other options.
      enable = true;
      name = "Banana";
      package = pkgs.banana-cursor;
      size = 40;
      gtk.enable = true;
    };
  };
}
