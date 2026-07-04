{
  inputs,
  lib,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../profiles/homelab.nix
    ../../../modules/nixos/hardware/audio.nix # PipeWire (ALSA + Pulse) for local playback
    ../../../modules/nixos/media # media automation stack
    inputs.disko.nixosModules.disko
    ./disko.nix # ZFS layout — also generates fileSystems for the legacy mounts
    ./hardware.nix
  ];

  # nixpkgs.config.allowUnfree and nix.settings.experimental-features are set
  # by the homelab profile.

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

  # ----------------------------------------------------------------------
  # Audio — local playback out of an attached device (HDMI / analog / USB
  # DAC). PipeWire itself comes from the imported hardware/audio.nix module.
  # rtkit lets PipeWire acquire realtime scheduling priority (avoids xruns).
  # jie is in the `audio` group because this box is driven over SSH, which
  # has no seat session to hand out /dev/snd ACLs the way a local login would.
  # ----------------------------------------------------------------------
  security.rtkit.enable = true;

  # GPU / graphics stack — DRI, Mesa/VAAPI, plus 32-bit userspace for apps
  # that need it. Enables accelerated HDMI output and video decode.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "audio"];
    # Password "hhkb", hashed with `mkpasswd -m sha-512`. Declaratively
    # enforced on every activation (so it overrides any prior password).
    hashedPassword = "$6$NaYrMFkyg/51ai9u$SN4xf/HNtsfg9SqcovSm1jgghFBfozkmHDZ5EEalN0/r1r9pI.qLKpTlMgQk5/h6UkpfKSS0tatv5UEmUFHAb.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxEzB8rb/S0bPaTymoXEj0OFj7FXy2XTapYXLJBMBkj"
    ];
  };

  # ----------------------------------------------------------------------
  # Transmission — BitTorrent daemon. Downloads land on the tank pool under
  # the media dataset. RPC/web UI is restricted to the home LAN with no
  # password (network-trust model); the module auto-adds download-dir and
  # incomplete-dir to the unit's ReadWritePaths and creates them owned by
  # the `transmission` user, so writing under /tank/media needs no chown.
  # ----------------------------------------------------------------------
  services.transmission = {
    enable = true;
    openFirewall = true; # peer port 51413 (tcp+udp)
    settings = {
      umask = 2; # octal 002 — downloaded files land group-writable (group `media`)
      download-dir = "/tank/media/downloads";
      incomplete-dir = "/tank/media/downloads/.incomplete";
      incomplete-dir-enabled = true;

      rpc-bind-address = "0.0.0.0"; # listen on the LAN, not just loopback
      rpc-port = 9091;
      rpc-authentication-required = false; # trusted-LAN model
      rpc-whitelist-enabled = true;
      rpc-whitelist = "127.0.0.1,192.168.86.*"; # app-level IP restriction
      rpc-host-whitelist-enabled = false; # avoid 403 when hitting the UI by IP
    };
  };

  # NOTE: /tank/media/{downloads,library} dirs + perms are created by
  # modules/nixos/media/storage.nix (2775, group `media`). Transmission's
  # download-dir must pre-exist for its BindPaths sandbox, and tmpfiles there
  # (ordered before transmission.service) provides it.

  # Transmission joins the shared media group so *arr apps (also in `media`) can
  # read its finished downloads and hardlink them into the library.
  users.users.transmission.extraGroups = ["media"];

  # Web UI (9091) reachable only from the home subnet. extraInputRules is
  # nftables syntax, so the firewall runs on the nftables backend (it
  # regenerates all existing rules, SSH included, equivalently).
  networking.nftables.enable = true;
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 9091 accept
  '';

  # Run-time linker shim so unpatched, dynamically-linked binaries (e.g. tools
  # fetched by language toolchains) can find an ld.so and the usual libraries
  # under /run/current-system/sw/share/nix-ld/lib.
  programs.nix-ld.enable = true;

  # ----------------------------------------------------------------------
  # Podman — rootless-capable container runtime. dockerCompat installs a
  # `docker` shim so docker-cli/compose invocations transparently drive
  # podman. DNS in the default network lets containers resolve each other
  # by name (needed by most compose stacks).
  # ----------------------------------------------------------------------
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = with pkgs; [
    git
    helix
    btop
    tmux
    alsa-utils # aplay -l / speaker-test to enumerate and test outputs
  ];

  system.stateVersion = "26.05";
}
