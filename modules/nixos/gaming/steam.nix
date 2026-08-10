# Steam itself, the gamescope "steam" session, and the shared game library.
{
  pkgs,
  user,
  ...
}: {
  # programs.steam.enable already turns on hardware.steam-hardware (controller
  # udev rules) and 32-bit audio, and installs the `steam-gamescope` launcher
  # onto the system PATH. Unfree is already allowed by the homelab profile;
  # 32-bit graphics is enabled on the host.
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
      # Deliberately NO --cursor-scale-height: it linearly upscales whatever
      # bitmap the client supplies, so a 24px cursor blown up 3× is just blurry.
      # A natively-large cursor theme (XCURSOR_SIZE in appearance.nix) is sharp
      # instead.
    ];
  };

  # gamescope is auto-enabled by gamescopeSession, so this only needs `enable`.
  # We deliberately do NOT set capSysNice: the NixOS security wrapper grants
  # gamescope *inheritable* CAP_SYS_NICE (getcap shows `cap_sys_nice=eip`), and
  # that inheritable cap leaks into Steam's bubblewrap sandbox, which aborts with
  # "bwrap: Unexpected capabilities but not setuid" → Steam never launches and
  # the session dies in ~1s, falling back to the greeter. Losing gamescope's
  # realtime scheduling priority is a minor frame-pacing cost; a Steam that
  # actually starts is the point.
  programs.gamescope.enable = true;

  # Performance CPU governor while a game is running.
  programs.gamemode.enable = true;

  # Re-downloadable game libraries live on fast/games (see disko.nix). The
  # dataset mounts as root:games with setgid (2775), so every child inherits the
  # shared group. jie is a member (takes effect on next login).
  #
  # ⚠️  Registering /fast/games as a Steam library is NOT declarable here: the
  #     library list is Steam client state in
  #     ~/.local/share/Steam/{config,steamapps}/libraryfolders.vdf, and Steam
  #     only auto-detects removable/SD media — never an internal mountpoint. It
  #     has been added by hand; if it ever goes missing, re-add it with Steam
  #     STOPPED (Steam rewrites the file on exit, clobbering live edits):
  #       game-stop  →  add an entry with "path" "/fast/games" to BOTH vdfs
  #                  →  mkdir -p /fast/games/steamapps
  #                  →  sudo systemctl restart greetd
  #     Big Picture's Storage page has no folder browser (desktop-mode only),
  #     so the vdf edit is the only route on this box.
  users.groups.games = {};
  users.users.${user.me.username}.extraGroups = ["games"];
}
