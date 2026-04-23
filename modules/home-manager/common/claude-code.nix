{ pkgs, ... }:
let
  claude-plugins-official = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "cf62a6c02dc03db88da8eb7c61bdb9fd88da6326";
    sha256 = "d28cc99927aa4b2d09ee077d3043e2ecfcc6d09971677b53b6f1f2816b72889b";
  };
in
{
  programs.claude-code = {
    enable = true;
    settings = {
      effortLevel = "high";
      defaultMode = "auto";
      skipDangerousModePermissionPrompt = true;
      deny = [
        "Bash(python3 *)"
        "Bash(uv pip *)"
      ];
      attribution = {
        commit = "";
        pr = "";
      };
    };
    plugins = [
      (pkgs.fetchFromGitHub {
        owner = "obra";
        repo = "superpowers";
        rev = "v5.0.7";
        sha256 = "1d0b4ef5c65f3cf2241c38fae0d790b86f69f568522815645865a1664663668a";
      })
      "${claude-plugins-official}/plugins/skill-creator"
      "${claude-plugins-official}/plugins/code-review"
      "${claude-plugins-official}/plugins/code-simplifier"
      "${claude-plugins-official}/plugins/agent-sdk-dev"
      "${claude-plugins-official}/plugins/ralph-loop"
      (pkgs.fetchFromGitHub {
        owner = "openai";
        repo = "codex-plugin-cc";
        rev = "v1.0.4";
        sha256 = "cd675dcf5f1cdc4d794cfb84be3324064af088594add9a881b960fe715fa6482";
      })
    ];
  };
}
