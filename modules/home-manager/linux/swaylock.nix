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

  # Lock on suspend, and auto-lock when idle.
  #
  # This must NOT be a user unit ordered against sleep.target: the system
  # manager reaches sleep.target but never propagates it into user managers,
  # so such a unit is installed into a target that never starts and the
  # screen silently stays unlocked across suspend. It also could not win the
  # race against `Successfully froze unit 'user.slice'` at suspend entry.
  #
  # swayidle -w instead takes a logind *delay* inhibitor for before-sleep and
  # waits for swaylock to return before releasing it, so the lock surface is
  # up before the kernel suspends. swaylock's `daemonize` forks only after
  # the screen is locked, which is exactly the handshake -w needs.
  services.swayidle = {
    enable = true;
    events = [
      {
        event = "before-sleep";
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
    ];
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        # DPMS off shortly after the lock, not instead of it.
        timeout = 330;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
      }
      {
        timeout = 1800;
        command = "${pkgs.systemd}/bin/systemctl suspend";
      }
    ];
  };
}
