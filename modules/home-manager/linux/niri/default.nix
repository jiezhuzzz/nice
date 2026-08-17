{
  config,
  pkgs,
  ...
}: let
  noctalia = "${config.programs.noctalia.package}/bin/noctalia";
  handleLidClose = pkgs.writeShellScript "noctalia-handle-lid-close" ''
    set -euo pipefail

    outputs="$(${pkgs.niri}/bin/niri msg --json outputs)"
    if ${pkgs.jq}/bin/jq -e '
      [to_entries[] | select(.key != "eDP-1" and .value.logical != null)]
      | length > 0
    ' <<<"$outputs" >/dev/null; then
      exit 0
    fi

    exec ${noctalia} msg session lock-and-suspend
  '';
in {
  # niri is enabled system-side by modules/nixos/desktop/niri.nix, which uses
  # the nixpkgs module (programs.niri.enable). That module offers enable,
  # package and useNautilus only — it has no config generator, and
  # home-manager has no niri module upstream, so the compositor config is
  # hand-maintained KDL in ./config.kdl.
  #
  # This module previously used niri-flake's `programs.niri.settings`, which
  # generated the KDL from typed Nix. Dropping that input removed four
  # transitive lock entries and a version skew: niri-flake's home-manager
  # module defaulted to niri 25.08 while the system actually runs the nixpkgs
  # niri (26.04 at the time of the change). The cost is that the KDL is
  # unvalidated at eval time — `niri validate` against the rendered file is
  # the check.
  #
  # replaceVars fills the two values only Nix can supply — @handleLidClose@
  # and @noctalia@ — and fails the build if either placeholder goes stale.
  xdg.configFile."niri/config.kdl".source = pkgs.replaceVars ./config.kdl {
    inherit handleLidClose noctalia;
  };

  home.packages = with pkgs; [
    brightnessctl # CLI backlight control; the keys go through noctalia now
    wl-clipboard # wl-copy/wl-paste; no CLI equivalent in noctalia's clipboard panel
  ];
}
