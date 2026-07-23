{
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs.stdenv) isDarwin;
  rimeDir =
    if isDarwin
    then "Library/Rime"
    else ".local/share/fcitx5/rime";
in {
  home.file."${rimeDir}/default.custom.yaml".text = builtins.toJSON {
    patch = {
      # nixpkgs renames rime-ice's default.yaml to avoid colliding with the
      # frontend's base data. Include it before applying local overrides.
      __include = "rime_ice_suggestion:/";
      schema_list = [{schema = "double_pinyin_flypy";}];
      # Only left Shift toggles EN/中; right Shift is inert. The default
      # binds both Shift keys — this replaces the whole switch_key map.
      "ascii_composer/switch_key" = {
        Shift_L = "inline_ascii";
        Shift_R = "noop";
        Control_L = "noop";
        Control_R = "noop";
        Caps_Lock = "clear";
      };
    };
  };

  # rime-ice's secondary translators default to full-pinyin spelling rules.
  # Apply its Xiaohe-specific rule sets so English and radical lookup behave
  # consistently with the selected schema.
  home.file."${rimeDir}/melt_eng.custom.yaml".text = builtins.toJSON {
    patch."speller/algebra".__include = "melt_eng.schema.yaml:/algebra_flypy";
  };

  home.file."${rimeDir}/radical_pinyin.custom.yaml".text = builtins.toJSON {
    patch."speller/algebra".__include = "radical_pinyin.schema.yaml:/algebra_flypy";
  };

  home.file."${rimeDir}" = {
    source = "${pkgs.rime-ice}/share/rime-data";
    recursive = true;
  };

  home.file."Library/Rime/squirrel.custom.yaml" = {
    enable = isDarwin;
    text = ''
      patch:
        style/candidate_list_layout: linear
        style/inline_preedit: true
    '';
  };

  # Rime's deployer only recompiles when a source file is newer than the
  # compiled output in build/. Our source data is symlinked from the Nix
  # store, where every file has a fixed 1970 mtime, so Rime always thinks
  # nothing changed and serves a stale build/ — config edits appear to do
  # nothing until build/ is wiped. Clear it on every activation, then kick a
  # redeploy on Darwin so the new config takes effect without manual steps.
  home.activation.rimeRedeploy = lib.hm.dag.entryAfter ["writeBoundary"] (
    ''
      run rm -rf $VERBOSE_ARG "$HOME/${rimeDir}/build"
    ''
    + lib.optionalString isDarwin ''
      squirrel="/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel"
      if [ -x "$squirrel" ]; then
        run "$squirrel" --reload || true
      fi
    ''
  );
}
