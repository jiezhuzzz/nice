{config, ...}: let
  tokenPath = "${config.xdg.dataHome}/rclone/gdrive-token";
in {
  programs.rclone = {
    enable = true;
    remotes.gdrive = {
      config = {
        type = "drive";
        scope = "drive";
      };
      secrets.token = tokenPath;
      mounts."" = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/GDrive";
        options = {
          vfs-cache-mode = "writes";
          vfs-cache-max-size = "10G";
          dir-cache-time = "1h";
          umask = "022";
        };
      };
    };
  };
}
