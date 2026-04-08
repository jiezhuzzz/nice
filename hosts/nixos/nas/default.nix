{...}: let
  user = import ../../../users/jie.nix;
in {
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "nas";

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

  # TODO: add hardware.nix once nixos-generate-config has been run on the box
  # imports = imports ++ [ ./hardware.nix ];

  # Placeholder file systems so the config evaluates. REPLACE when real
  # hardware config exists.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  system.stateVersion = "26.05";
}
