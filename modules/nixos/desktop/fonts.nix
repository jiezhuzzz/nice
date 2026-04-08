{pkgs, ...}: {
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    maple-mono.NF

    # Latin
    noto-fonts

    # CJK
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    lxgw-wenkai # handwriting-style Chinese (kept for reading/decorative)
    source-han-sans # PingFang-alike default (思源黑体)
    source-han-serif # serif companion (思源宋体)

    # Emoji
    noto-fonts-color-emoji
  ];

  # Latin first, Simplified-Chinese as explicit fallback. Without the SC
  # pin, fontconfig may pick TC/JP/KR glyphs for ambiguous Han characters
  # (wrong strokes for a Chinese reader).
  # Chinese default: Source Han Sans SC — the canonical open substitute
  # for Apple's PingFang SC (same modern, neutral sans-serif style).
  fonts.fontconfig.defaultFonts = {
    sansSerif = ["Noto Sans" "Source Han Sans SC"];
    serif = ["Noto Serif" "Source Han Serif SC"];
    monospace = ["JetBrainsMono Nerd Font" "Source Han Sans SC"];
    emoji = ["Noto Color Emoji"];
  };
}
