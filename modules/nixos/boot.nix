{pkgs, ...}: {
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 0; # Hold Space during boot for menu
  boot.loader.efi.canTouchEfiVariables = true;

  # Esc drops from the splash to the plain-text LUKS prompt.
  boot.plymouth.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
}
