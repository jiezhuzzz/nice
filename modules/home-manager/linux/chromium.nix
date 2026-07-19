{pkgs, ...}: {
  # ungoogled-chromium: Chromium with Google integration and background
  # requests stripped out. The binary is still `chromium`, which is what the
  # niri Alt+B bind and the xremap browser rule spawn/match on.
  programs.chromium = {
    enable = true;
    package = pkgs.ungoogled-chromium;
  };
}
