{inputs, ...}: {
  imports = [inputs.xremap-flake.homeManagerModules.default];

  # One user-level remapper owns all keyboard transformations. The first
  # matching xremap rule wins, so the Chromium-specific Alt rule must precede
  # the global macOS-style modifier swap.
  services.xremap = {
    enable = true;
    withNiri = true;
    watch = true;
    config.modmap = [
      {
        name = "Chromium Command key";
        application.only = ["/(?i)chromium/"];
        remap = {
          Alt_L = "Control_L";
          Alt_R = "Control_R";
        };
      }
      {
        name = "macOS-style modifiers";
        remap = {
          Alt_L = "Super_L";
          Alt_R = "Super_R";
          Super_L = "Alt_L";
          Super_R = "Alt_R";
        };
      }
      {
        name = "Dual-role keys";
        remap = {
          CapsLock = {
            held = "Control_L";
            alone = "Esc";
            hold_threshold_millis = 0;
            alone_timeout_millis = 100;
          };
          Shift_L = {
            held = "Shift_L";
            alone = ["Control_L" "Space"];
            hold_threshold_millis = 0;
            alone_timeout_millis = 100;
          };
          Shift_R = {
            held = "Shift_R";
            alone = ["Control_L" "Space"];
            hold_threshold_millis = 0;
            alone_timeout_millis = 100;
          };
        };
      }
    ];
  };

  # Niri publishes NIRI_SOCKET before graphical-session.target becomes active;
  # the explicit dependency also documents the application-filter requirement.
  systemd.user.services.xremap.Unit.After = ["niri.service"];
}
