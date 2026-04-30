{pkgs, ...}: let
  superpowers = pkgs.fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "v5.0.7";
    sha256 = "1d0b4ef5c65f3cf2241c38fae0d790b86f69f568522815645865a1664663668a";
    name = "superpowers";
  };
in {
  programs.codex = {
    enable = true;
    # skills = {
    #   "superpowers" = "${superpowers}/skills";
    # };
    # settings = {
    #   model = "gpt-5.5";
    #   model_reasoning_effort = "high";
    #   approval_policy = "on-request";
    #   sandbox_mode = "workspace-write";
    #   # Activate with `codex --profile server` on hosts that need the
    #   # US-region OpenAI endpoint (e.g. chameleon).
    #   profiles.server = {
    #     openai_base_url = "https://us.api.openai.com/v1";
    #     model = "gpt-5.4";
    #   };
    # };
    # context = ''
    #   # Python

    #   - Always use `uv` to run Python scripts, never `python` or `python3` directly.
    #   - Run scripts with `uv run script.py`, never `python script.py`.
    #   - When writing Python scripts, use PEP 723 inline script metadata to declare dependencies:
    #     ```python
    #     # /// script
    #     # dependencies = [
    #     #   "requests<3",
    #     #   "rich",
    #     # ]
    #     # ///
    #     ```
    #     This lets `uv run script.py` automatically install dependencies without a separate install step.
    #   - Do not use `pip install`, `pip3 install`, or `uv add` for standalone scripts. Inline the dependencies instead.
    #   - For Python projects (not standalone scripts), use `uv init`, `uv add`, and `uv run`.
    #   - Use `uv run` to execute any Python tooling (pytest, ruff, mypy, etc.).
    # '';
    # rules.deny-python = ''
    #   prefix_rule(pattern = ["python"], decision = "deny", justification = "Use uv run instead of python directly")
    #   prefix_rule(pattern = ["python3"], decision = "deny", justification = "Use uv run instead of python3 directly")
    #   prefix_rule(pattern = ["pip"], decision = "deny", justification = "Use uv for dependency management")
    #   prefix_rule(pattern = ["pip3"], decision = "deny", justification = "Use uv for dependency management")
    #   prefix_rule(pattern = ["uv", "pip"], decision = "deny", justification = "Use uv add or inline script metadata instead")
    # '';
  };
}
