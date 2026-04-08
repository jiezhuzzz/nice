{pkgs, ...}: {
  # Chinese input method (Rime via fcitx5)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      (fcitx5-rime.override {rimeDataPkgs = [rime-ice];})
    ];
  };
}
