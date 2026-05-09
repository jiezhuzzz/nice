{config, ...}: let
  gdriveTokenPath = "${config.xdg.dataHome}/rclone/gdrive-token";
  boxTokenPath = "${config.xdg.dataHome}/rclone/box-token";
  mountOptions = {
    vfs-cache-mode = "writes";
    vfs-cache-max-size = "10G";
    dir-cache-time = "1h";
    umask = "022";
  };
in {
  programs.rclone = {
    enable = true;
    remotes.gdrive = {
      config = {
        type = "drive";
        scope = "drive";
      };
      secrets.token = gdriveTokenPath;
      mounts."" = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/GDrive";
        options = mountOptions;
      };
    };
    remotes.box = {
      config = {
        type = "box";
      };
      secrets.token = boxTokenPath;
      mounts."" = {
        enable = true;
        autoMount = true;
        mountPoint = "${config.home.homeDirectory}/Box";
        options = mountOptions;
      };
    };
  };
}
