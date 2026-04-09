{pkgs, ...}: let
  isDarwin = pkgs.stdenv.isDarwin;
  rimeDir =
    if isDarwin
    then "Library/Rime"
    else ".local/share/fcitx5/rime";
in {
  home.file."${rimeDir}/default.custom.yaml".text = builtins.toJSON {
    patch.schema_list = [{schema = "double_pinyin_flypy";}];
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
