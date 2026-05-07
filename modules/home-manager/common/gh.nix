{pkgs, ...}: let
  user = import ../../../users/jie.nix;
in {
  programs.gh = {
    enable = true;

    # hosts.yml — token is NOT stored here; gh keeps it in macOS Keychain
    # under service "gh:github.com" (see `gh auth status`, marked "(keyring)").
    hosts = {
      "github.com" = {
        git_protocol = "ssh";
        user = user.me.fullname;
        users.${user.me.fullname} = null;
      };
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
