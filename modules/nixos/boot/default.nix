{pkgs, ...}: {
  # systemd-boot EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 0; # Hold Space during boot for menu
  boot.loader.efi.canTouchEfiVariables = true;

  # Graphical boot splash with LUKS password prompt (Esc for text)
  boot.plymouth.enable = true;

  # Latest kernel
  # TODO: Switch to 7.0+ when available for Dell XPS 14 (Panther Lake)
  # CS42L45 audio — https://github.com/thesofproject/linux/issues/5720
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Prevent kernel crash in sdca_jack_process on PTL — CS42L45 missing in 6.19
  # Remove when upgrading to kernel 7.0+
  boot.extraModprobeConfig = ''
    options snd_sof disable_function_topology=1
  '';
}
