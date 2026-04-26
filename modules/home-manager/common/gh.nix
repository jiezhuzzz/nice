{pkgs, ...}: {
  programs.gh = {
    enable = true;
    settings = {
      prompt = "enabled";
      git_protocol = "ssh";
    };
    extensions = with pkgs; [
      gh-dash
      gh-poi
      gh-eco
      gh-s
      gh-f
    ];
  };
}
