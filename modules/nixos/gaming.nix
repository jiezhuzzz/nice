# modules/nixos/gaming.nix
# Console-like Steam gaming session for nixmachine.
#
# Boots straight into gamescope → Steam Big Picture (SteamOS-style) via greetd
# autologin, on the AMD GPU (Mesa/RADV). The homelab services (media / LLM /
# stirling-pdf / sshd) are independent systemd units and keep running
# underneath — SSH works before, during, and after gaming.
#
# Exit behaviour: quitting Steam ends the gamescope session; greetd then shows a
# plain agreety text login on the monitor (console-blanks on idle). The box is
# functionally headless again — just SSH in as usual.
#
# ⚠️  Steam Big Picture's power menu Shutdown / Restart powers off the WHOLE box,
#     killing the 24/7 homelab services. To return to server mode use Big
#     Picture's plain "Exit" (quit Steam), NOT Shutdown.
{pkgs, ...}: let
  user = import ../../users/jie.nix;
in {
  # Steam + the gamescope "steam" session. programs.steam.enable already turns
  # on hardware.steam-hardware (controller udev rules) and 32-bit audio, and
  # installs the `steam-gamescope` launcher onto the system PATH. Unfree is
  # already allowed by the homelab profile; 32-bit graphics is enabled on the
  # host.
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  # gamescope compositor. capSysNice lets it request realtime priority for
  # smoother frame pacing.
  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  # Performance CPU governor while a game is running.
  programs.gamemode.enable = true;

  # greetd: a minimal login daemon (no graphical greeter). It opens a logind
  # seat session so gamescope can reach the GPU (DRM/KMS) and input devices.
  #   initial_session → runs once at boot: autologin jie straight into Steam.
  #   default_session → shown after Steam exits: a plain text login prompt.
  # Setting initial_session flips services.greetd.restart to false by default,
  # so the autologin fires exactly once (no relaunch loop).
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "steam-gamescope"; # on PATH via programs.steam.gamescopeSession
        user = user.me.username;
      };
      default_session = {
        command = "${pkgs.greetd}/bin/agreety --cmd $SHELL";
        # user defaults to "greeter"
      };
    };
  };
}
