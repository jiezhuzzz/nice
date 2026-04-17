{pkgs, ...}: {
  programs.zed-editor.enable = true;
  programs.zed-editor.package =
    if pkgs.stdenv.isDarwin
    then null
    else pkgs.zed-editor;
  programs.zed-editor.userSettings = {
    buffer_font_family = "JetBrainsMono Nerd Font";
    buffer_font_size = 14;
  };
}
