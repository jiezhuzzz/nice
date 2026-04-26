{pkgs, ...}: let
  claude-plugins-official = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "cf62a6c02dc03db88da8eb7c61bdb9fd88da6326";
    sha256 = "d28cc99927aa4b2d09ee077d3043e2ecfcc6d09971677b53b6f1f2816b72889b";
  };
  codex-plugin-cc = pkgs.fetchFromGitHub {
    owner = "openai";
    repo = "codex-plugin-cc";
    rev = "v1.0.4";
    sha256 = "cd675dcf5f1cdc4d794cfb84be3324064af088594add9a881b960fe715fa6482";
  };
in {
  programs.claude-code = {
    enable = true;
    skills = ../../../skills;
    settings = {
      model = "claude-opus-4-7[1m]";
      effortLevel = "xhigh";
      defaultMode = "auto";
      skipDangerousModePermissionPrompt = true;
      deny = [
        "Bash(python *)"
        "Bash(python3 *)"
        "Bash(pip *)"
        "Bash(pip3 *)"
        "Bash(uv pip *)"
      ];
      attribution = {
        commit = "";
        pr = "";
      };
    };
    context = ''
      # Python

      - Always use `uv` to run Python scripts, never `python` or `python3` directly.
      - Run scripts with `uv run script.py`, never `python script.py`.
      - When writing Python scripts, use PEP 723 inline script metadata to declare dependencies:
        ```python
        # /// script
        # dependencies = [
        #   "requests<3",
        #   "rich",
        # ]
        # ///
        ```
        This lets `uv run script.py` automatically install dependencies without a separate install step.
      - Do not use `pip install`, `pip3 install`, or `uv add` for standalone scripts. Inline the dependencies instead.
      - For Python projects (not standalone scripts), use `uv init`, `uv add`, and `uv run`.
      - Use `uv run` to execute any Python tooling (pytest, ruff, mypy, etc.).
    '';
    plugins = [
      (pkgs.fetchFromGitHub {
        owner = "obra";
        repo = "superpowers";
        rev = "v5.0.7";
        sha256 = "1d0b4ef5c65f3cf2241c38fae0d790b86f69f568522815645865a1664663668a";
        name = "superpowers";
      })
      "${claude-plugins-official}/plugins/skill-creator"
      "${claude-plugins-official}/plugins/code-review"
      "${claude-plugins-official}/plugins/code-simplifier"
      "${claude-plugins-official}/plugins/agent-sdk-dev"
      "${claude-plugins-official}/plugins/ralph-loop"
      "${codex-plugin-cc}/plugins/codex"
    ];
  };
}
