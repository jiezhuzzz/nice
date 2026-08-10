# Ten-foot-UI legibility on the 4K panel: a natively-large cursor theme and a
# readable MangoHud overlay.
{pkgs, ...}: {
  # The gamescope session's `--mangoapp` flag launches the `mangoapp` binary
  # (from mangohud) directly from gamescope — which lives OUTSIDE Steam's FHS, so
  # the mangohud in programs.steam.extraPackages (steam.nix) isn't visible to it.
  # Put it on the system PATH so gamescope can find it (else: endless "Failed to
  # start process mangoapp" errors).
  environment.systemPackages = [
    pkgs.mangohud
    pkgs.banana-cursor # cursor theme, see XCURSOR_* below
  ];

  # Cursor. This host had no cursor theme at all, so libXcursor fell back to a
  # 24px default — invisible on a 2160p panel, and unfixable by scaling (see the
  # --cursor-scale-height note in steam.nix).
  #
  # Banana is the same theme nixps uses (profiles/nixos-desktop.nix), and it
  # ships native bitmaps at 16/20/22/24/28/32/40/48/56/64/72/80/88/96, so 96
  # is drawn 1:1 with no resampling. nixps sets 40 for a 1440p desktop; a 4K
  # ten-foot UI wants roughly this much more.
  #
  # sessionVariables (not the session wrapper in session.nix) because these must
  # apply however the session starts — greetd autologin or a bare
  # `steam-gamescope` from a console login. Both go through PAM, which is what
  # sets these.
  environment.sessionVariables = {
    XCURSOR_THEME = "Banana";
    XCURSOR_SIZE = "96";
  };

  # MangoHud defaults to a 24px font, which is unreadable on a 2160p panel at
  # couch distance. It resolves config in this order: $MANGOHUD_CONFIGFILE →
  # ~/.config/MangoHud/{<app>,MangoHud}.conf → /etc/MangoHud.conf. Using the
  # /etc fallback keeps this working no matter how the session is launched
  # (greetd wrapper or a bare `steam-gamescope` from the console), and leaves
  # the per-user paths free to override it.
  # font_scale is a plain multiplier over every element, so the overlay box
  # grows with the text. Bump it if 2.5× still reads small.
  environment.etc."MangoHud.conf".text = ''
    font_scale=5
  '';
}
