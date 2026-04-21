{pkgs, ...}: {
  home.packages = with pkgs; [
    uv
    comma
    yubikey-manager
  ];
}
