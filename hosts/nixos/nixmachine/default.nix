{
  inputs,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../../../profiles/homelab.nix
    ../../../modules/nixos/hardware/audio.nix # PipeWire (ALSA + Pulse) for local playback
    # fwupd, so the Framework Desktop's BIOS can be updated from LVFS rather
    # than an EFI-shell USB stick. Imported as a leaf rather than through
    # hardware/default.nix: that bundle also carries power/bluetooth/touchpad,
    # which are laptop concerns. Also flips on hardware.enableAllFirmware.
    ../../../modules/nixos/hardware/firmware.nix
    ../../../modules/nixos/media
    ../../../modules/nixos/litellm.nix # LLM gateway holding the provider keys
    ../../../modules/nixos/stirling-pdf.nix # self-hosted PDF toolkit
    ../../../modules/nixos/karakeep.nix # self-hosted bookmark-everything app
    ../../../modules/nixos/vaultwarden.nix # password vault — tailnet-only, no LAN port
    ../../../modules/nixos/memos.nix # note-taking — tailnet-only, no LAN port
    ../../../modules/nixos/miniflux.nix # RSS reader — tailnet-only, no LAN port
    ../../../modules/nixos/rsshub.nix # feed generator for sites without one
    ../../../modules/nixos/xuewen.nix # paper manager — tailnet-only, no LAN port
    ../../../modules/nixos/mdns.nix # Avahi mDNS — nixmachine.local resolves on the LAN
    ../../../modules/nixos/glance.nix # homelab dashboard at nixmachine.local:8083
    ../../../modules/nixos/searxng.nix # self-hosted metasearch — pi's web_search backend
    ../../../modules/nixos/tailscale.nix # mesh VPN — remote access path (SSH + caddy.nix)
    ../../../modules/nixos/caddy.nix # HTTPS names on *.jiezhu.me over the tailnet
    ../../../modules/nixos/gaming # console-like Steam gamescope session (local play)
    inputs.disko.nixosModules.disko
    ./disko.nix # ZFS layout — also generates fileSystems for the legacy mounts
    ./hardware.nix
  ];

  networking.hostName = "nixmachine";
  # Required by ZFS: a stable 8-hex-digit host id (guards against importing a
  # pool last touched by a different machine). Generated once; keep it.
  networking.hostId = "1d847e7e";

  time.timeZone = "America/Chicago";

  # Boot — systemd-boot on the primary ESP (/boot). The disko layout also
  # mounts a second ESP at /boot/.fallback on the other NVMe; it's a spare
  # you sync by hand (systemd-boot doesn't mirror ESPs natively).
  # Deliberately NOT pinning linuxPackages_latest: ZFS lags the newest
  # kernel, so we ride NixOS's default (ZFS-compatible) kernel.
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

  # nftables firewall backend — modern choice (replaces iptables).
  networking.nftables.enable = true;

  # Headless access — key-only, no password over SSH (jie has an authorized key
  # below). The console password (initialPassword) still works for physical
  # recovery.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  # Audio — local playback out of an attached device (HDMI / analog / USB
  # DAC). PipeWire itself comes from the imported hardware/audio.nix module.
  # rtkit lets PipeWire acquire realtime scheduling priority (avoids xruns).
  # jie is in the `audio` group because this box is driven over SSH, which
  # has no seat session to hand out /dev/snd ACLs the way a local login would.
  security.rtkit.enable = true;

  # GPU / graphics stack — DRI, Mesa/VAAPI, plus 32-bit userspace for apps
  # that need it. Enables accelerated HDMI output and video decode.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "audio" "media"];
    # Runs jie's systemd user manager at boot, not just during an SSH session —
    # what keeps the dsh-web user unit below up.
    linger = true;
    # Password "hhkb", hashed with `mkpasswd -m sha-512`. Declaratively
    # enforced on every activation (so it overrides any prior password).
    hashedPassword = "$6$NaYrMFkyg/51ai9u$SN4xf/HNtsfg9SqcovSm1jgghFBfozkmHDZ5EEalN0/r1r9pI.qLKpTlMgQk5/h6UkpfKSS0tatv5UEmUFHAb.";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDxEzB8rb/S0bPaTymoXEj0OFj7FXy2XTapYXLJBMBkj"
    ];
  };

  # On top of the server bundle profiles/homelab.nix hands jie.
  home-manager.users.${user.me.username}.imports = [
    ../../../modules/home-manager/linux/dsh.nix
  ];

  # Podman — rootless-capable container runtime. Keep the Docker CLI shim
  # disabled so callers explicitly select Podman. DNS in the default network
  # lets containers resolve each other by name (needed by most compose stacks).
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = with pkgs; [
    git
    helix
    btop
    tmux
    jq
    wget
    skopeo # inspect/copy container images (e.g. resolve pinned digests for podman)
    alsa-utils # aplay -l / speaker-test to enumerate and test outputs
  ];

  system.stateVersion = "26.05";
}
