_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;

    # Exposes BlueZ's battery interface over D-Bus, so connected headphones
    # and mice report charge level. "Experimental" is BlueZ's own label for
    # the flag that gates it; battery reporting is the reason it is on.
    settings.General.Experimental = true;
  };

  # No blueman or GUI pairing tool: noctalia-shell has a bluetooth panel that
  # drives BlueZ over D-Bus, and bluetoothctl covers the rest.
}
