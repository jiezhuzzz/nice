{pkgs, ...}: {
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.inconsolata
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
    # Disabled: pulls in afdko, whose test suite crashes on aarch64-darwin
    # and fails the build (upstream adobe-type-tools/afdko#1216).
    # noto-fonts-color-emoji
  ];
}
