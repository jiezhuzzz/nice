{pkgs, ...}: {
  # ungoogled-chromium: Chromium with Google integration and background
  # requests stripped out. The binary is still `chromium`, which is what the
  # niri Alt+B bind spawns.
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
    commandLineArgs = [
      "--force-device-scale-factor=1.25"
      # Under native Wayland, Chromium ignores GTK_IM_MODULE/XMODIFIERS and only
      # talks to fcitx5 via the text-input protocol, which it does not enable by
      # default. Without this flag Rime can't be switched to at all. Pin v3 to
      # avoid the buggy v1 path some compositors negotiate (niri supports v3).
      "--enable-wayland-ime"
      "--wayland-text-input-version=3"
    ];
  };
}
