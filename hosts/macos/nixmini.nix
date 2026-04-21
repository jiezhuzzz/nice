{...}: {
  imports = [../../profiles/darwin-desktop.nix];
  networking.hostName = "nixmini";
  networking.computerName = "nixmini";
  home-manager.backupFileExtension = "backup";
}
