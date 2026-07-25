{
  inputs,
  pkgs,
  ...
}: {
  # noctalia-greeter: a graphical greetd login screen that matches noctalia-shell
  # (the desktop, see modules/home-manager/linux/noctalia.nix). It runs inside a
  # bundled wlroots compositor and lets you pick user/session/scheme before niri
  # starts. Replaces the previous greetd + tuigreet setup.
  #
  # The upstream module owns the greetd plumbing: enabling it sets
  # `services.greetd.enable` and `default_session.command` (both mkDefault) to
  # `noctalia-greeter-session -- <greeter-args>`, and installs the package —
  # which also ships the polkit action that powers "Sync Now" (below). So this
  # module must NOT configure `services.greetd` by hand.
  imports = [inputs.noctalia-greeter.nixosModules.default];

  programs.noctalia-greeter = {
    enable = true;

    # Preselect niri (the only session on this host). If the greeter ever stops
    # preselecting, the session Name may differ from "niri" — confirm the exact
    # spelling with `noctalia-greeter sessions`. A wrong name is harmless: it
    # just falls back to no preselection.
    greeter-args = "--session niri";

    # `settings` is written to /var/lib/noctalia-greeter/greeter.toml via a
    # systemd-tmpfiles copy-if-absent rule, so it is a one-time SEED: the greeter
    # then owns that file (persisting last-used session and colour scheme).
    # Editing these values later will not propagate unless that file is removed.
    #
    # Wallpaper and palette are deliberately omitted: run
    # Settings -> Shell -> Security -> Noctalia Greeter -> Sync Now in noctalia
    # to copy the live desktop appearance here (a "Synced" scheme appears), then
    # `systemctl restart greetd`. Hardcoding colours would fight that.
    settings = {
      cursor = {
        # Matches home.pointerCursor in profiles/nixos-desktop.nix, including its
        # deliberately large size for this high-density panel.
        theme = "Banana";
        size = 40;
        path = "${pkgs.banana-cursor}/share/icons";
      };
      keyboard.layout = "us";
    };
  };
}
