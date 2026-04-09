{pkgs, ...}: {
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    maple-mono.NF

    # Latin
    noto-fonts

    # CJK
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    lxgw-wenkai
    source-han-sans
    source-han-serif

    # Emoji
    noto-fonts-color-emoji
  ];
}
