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
    # afdko#1216 (the aarch64 test crash that blocked this) is fixed upstream;
    # nixpkgs afdko 5.0.1 handles arch-specific tests. Re-pin/disable only if a
    # darwin-rebuild build starts failing in the afdko dependency again.
    noto-fonts-color-emoji
  ];
}
