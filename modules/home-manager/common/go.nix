{config, ...}: {
  programs.go = {
    enable = true;
    # Toolchains come from per-project dev shells.
    package = null;
    env = {
      GOPATH = "${config.xdg.dataHome}/go";
      GOMODCACHE = "${config.xdg.cacheHome}/go/mod";
    };
  };
}
