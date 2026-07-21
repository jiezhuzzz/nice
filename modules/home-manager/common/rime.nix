{pkgs, ...}: let
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
}
