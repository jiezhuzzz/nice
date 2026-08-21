{pkgs, ...}: {
  home.packages = with pkgs; [
    ast-grep
    comma
    lazyrsync
    rsync
    tea
    yubikey-manager
  ];
}
