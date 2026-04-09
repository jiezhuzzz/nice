{pkgs, ...}: {
  programs.zed-editor.enable = true;
  programs.zed-editor.package =
    if pkgs.stdenv.isDarwin
    then null
    else pkgs.zed-editor;
}
