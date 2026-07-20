_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # No blueman or GUI pairing tool: noctalia-shell has a bluetooth panel that
  # drives BlueZ over D-Bus, and bluetoothctl covers the rest.
}
