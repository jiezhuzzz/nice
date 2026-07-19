{pkgs, ...}: {
  programs.swaylock = {
    enable = true;
    settings = {
      daemonize = true;
      ignore-empty-password = true;
      show-failed-attempts = true;
      indicator-caps-lock = true;
      indicator-radius = 120;
      indicator-thickness = 8;
    };
  };

  # Lock the screen before the system suspends, so resume requires the password.
  systemd.user.services.swaylock-on-sleep = {
    Unit = {
      Description = "Lock screen with swaylock before sleep";
      Before = ["sleep.target"];
    };
    Service = {
      Type = "forking";
      ExecStart = "${pkgs.swaylock}/bin/swaylock";
    };
    Install.WantedBy = ["sleep.target"];
  };
}
