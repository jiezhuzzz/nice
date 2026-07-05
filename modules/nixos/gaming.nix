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

    # GE-Proton as a selectable per-game compatibility tool — broader game
    # coverage than stock Proton.
    extraCompatPackages = [pkgs.proton-ge-bin];

    # Injected into Steam's FHS runtime: the MangoHud overlay and the gamescope
    # Vulkan WSI layer (the latter is what makes HDR / tearing control work under
    # gamescope).
    extraPackages = with pkgs; [
      mangohud
      gamescope-wsi
    ];

    gamescopeSession.enable = true;
    # gamescope session tuned for the attached 4K/120 Hz HDR display:
    #   -w / -h / -r → 3840×2160 @ 120 Hz   --hdr-enabled → HDR output (relies on
    #   the gamescope-wsi layer above)      --mangoapp    → MangoHud overlay
    #   --xwayland-count 2 and -e are the standard Steam-Deck-style session flags.
    # These are validated at runtime by gamescope on the actual hardware.
    gamescopeSession.args = [
      "-w 3840"
      "-h 2160"
      "-r 120"
      "--xwayland-count 2"
      "-e"
      "--hdr-enabled"
      "--mangoapp"
    ];
  };

  # gamescope compositor. Enabling gamescopeSession already defaults
  # programs.gamescope.enable to true; we keep this block for capSysNice, which
  # lets gamescope request realtime priority for smoother frame pacing.
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
