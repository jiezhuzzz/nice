{pkgs, ...}: {
  # The clickpad's physical button intermittently does not work after boot:
  # the pad tracks and taps fine, but a press produces no POINTER_BUTTON on
  # any input node — not even the Mouse node that advertises BTN_LEFT.
  # Re-binding the HID device to hid-multitouch restores it, so this is an
  # initialisation race rather than missing driver support. The kernel log
  # shows hid-generic claiming the device first and hid-multitouch taking
  # over afterwards, which is the kind of ordering that varies per boot.
  #
  # The rebind is unconditional: there is no way to detect the bad state
  # without a physical press, and rebinding a working device is harmless.
  systemd.services.touchpad-rebind = {
    description = "Rebind the I2C-HID touchpad so its physical click works";
    wantedBy = ["multi-user.target"];
    after = ["systemd-udev-settle.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "touchpad-rebind" ''
        drv=/sys/bus/hid/drivers/hid-multitouch
        # Matches this Synaptics pad by vendor:product, so the unit is a
        # no-op on machines without it rather than an error.
        for dev in "$drv"/*:06CB:D01D.*; do
          [ -e "$dev" ] || continue
          id=$(basename "$dev")
          echo -n "$id" > "$drv/unbind" || true
          sleep 1
          echo -n "$id" > "$drv/bind" || true
        done
      '';
    };
  };
}
