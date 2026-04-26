_: {
  # CapsLock → Esc (tap) / Ctrl (hold)
  # Alt ↔ Super swap (macOS-style): physical Alt keys act as Super (Cmd),
  # physical Super keys act as Alt. Applies to both left and right.
  # Shift → Shift (hold, normal modifier) / Ctrl+Space (tap, toggles fcitx5).
  services.kanata = {
    enable = true;
    keyboards.default = {
      devices = [];
      config = ''
        (defsrc
          caps lalt ralt lmet rmet lsft rsft
        )
        (defalias
          escctrl (tap-hold 100 100 esc lctl)
          lsftim (tap-hold-press 100 100 (macro C-spc) lsft)
          rsftim (tap-hold-press 100 100 (macro C-spc) rsft)
        )
        (deflayer default
          @escctrl lmet rmet lalt ralt @lsftim @rsftim
        )
      '';
    };
  };
}
