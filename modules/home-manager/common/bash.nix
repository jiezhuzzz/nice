{pkgs, ...}: {
  programs.bash = {
    enable = true;
    initExtra = ''
      source ${pkgs.blesh}/share/blesh/ble.sh
    '';
  };
}
