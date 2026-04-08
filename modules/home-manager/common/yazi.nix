{...}: {
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    # Adds a `y` shell function that cd's to yazi's last directory on exit.
  };
}
