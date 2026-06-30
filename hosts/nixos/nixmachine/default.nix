{
  inputs,
  lib,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix # ZFS layout — also generates fileSystems for the legacy mounts
    ./hardware.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  networking.hostName = "nixmachine";
  # Required by ZFS: a stable 8-hex-digit host id (guards against importing a
  # pool last touched by a different machine). Generated once; keep it.
  networking.hostId = "1d847e7e";

  time.timeZone = "America/Chicago";

  # ----------------------------------------------------------------------
  # Boot — systemd-boot on the primary ESP (/boot). The disko layout also
  # mounts a second ESP at /boot/.fallback on the other NVMe; it's a spare
  # you sync by hand (systemd-boot doesn't mirror ESPs natively).
  # Deliberately NOT pinning linuxPackages_latest: ZFS lags the newest
  # kernel, so we ride NixOS's default (ZFS-compatible) kernel.
  # ----------------------------------------------------------------------
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = ["zfs"];
  boot.zfs.forceImportRoot = false;

  services.zfs.autoScrub.enable = true; # monthly scrub
  services.zfs.trim.enable = true; # periodic TRIM for the NVMe-backed pools

  # No swap partition in the disko layout — use zram instead.
  zramSwap.enable = true;

  # Wired DHCP; headless box, so no NetworkManager.
  networking.useDHCP = lib.mkDefault true;

  # Headless access — key-only, no password over SSH (jie has an authorized key
  # below). The console password (initialPassword) still works for physical
  # recovery.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    # Password "hhkb", hashed with `mkpasswd -m sha-512`. Declaratively
    # enforced on every activation (so it overrides any prior password).
    hashedPassword = "$6$NaYrMFkyg/51ai9u$SN4xf/HNtsfg9SqcovSm1jgghFBfozkmHDZ5EEalN0/r1r9pI.qLKpTlMgQk5/h6UkpfKSS0tatv5UEmUFHAb.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxEzB8rb/S0bPaTymoXEj0OFj7FXy2XTapYXLJBMBkj"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    helix
    btop
    tmux
  ];

  system.stateVersion = "26.05";
}
