{pkgs, ...}: {
  home.packages = with pkgs; [
    zed-editor
    yubikey-manager
  ];
}
