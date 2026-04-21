{pkgs, ...}: {
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      source ${pkgs.blesh}/share/blesh/ble.sh --attach=none
    '';
    initExtra = ''
      [[ ! ''${BLE_VERSION-} ]] || ble-attach
    '';
  };
}
