_: {
  # Lid close behavior
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "ignore";
  };

  powerManagement.enable = true;
  services.thermald.enable = true;

  # D-Bus battery/AC reporting. The kernel exposes BAT0 either way, but
  # desktop clients read power state over UPower rather than sysfs — without
  # it, noctalia-shell's battery widget has no source and shows nothing.
  services.upower.enable = true;
  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "performance";
      turbo = "auto";
    };
  };
}
