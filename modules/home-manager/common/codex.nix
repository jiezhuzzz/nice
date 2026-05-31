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
    settings = {
      # Auto-review: route approval requests to Codex's Guardian reviewer
      # agent instead of pausing for the user. Only takes effect with
      # approval_policy = "on-request" (no requests to review under "never").
      approval_policy = "on-request";
      approvals_reviewer = "auto_review";
      sandbox_mode = "workspace-write";
      personality = "pragmatic";
      # Disable the Memories feature so Codex never auto-generates memories or
      # injects them into future sessions (off by default; pinned explicitly).
      features.memories = false;
      tui.notifications = true;
      # TUI footer status line (config-as-code for the /statusline picker).
      # Ordered list of item identifiers; defaults to
      # ["model-with-reasoning" "current-dir"] when unset, null disables it.
      # Other valid items: context-used, fast-mode, run-state,
      # branch-changes, pull-request-number. See `tui.status_line` in
      # codex-rs/core/config.schema.json upstream.
      tui.status_line = [
        "model-with-reasoning"
        "context-remaining"
        "five-hour-limit"
        "weekly-limit"
        "current-dir"
      ];
      # Always use the highest reasoning effort.
      # Valid: minimal | low | medium | high | xhigh.
      model_reasoning_effort = "xhigh";
      # model = "gpt-5.5";
      # # Activate with `codex --profile server` on hosts that need the
      # # US-region OpenAI endpoint (e.g. chameleon).
      # profiles.server = {
      #   openai_base_url = "https://us.api.openai.com/v1";
      #   model = "gpt-5.4";
      # };
    };
    # Soft guidance: Codex's equivalent of AGENTS.md, mirrors the uv policy
    # from the global CLAUDE.md so Codex prefers uv on its own.
    context = ''
      # Python

      - Always use `uv` to run Python scripts, never `python` or `python3` directly.
      - Run scripts with `uv run script.py`, never `python script.py`.
      - When writing a standalone Python script, declare its dependencies inline
        with PEP 723 (https://peps.python.org/pep-0723/) script metadata, then run
        it with `uv run script.py`. uv reads the metadata block, builds an
        ephemeral virtualenv with those deps, and runs the script — no separate
        install step, no project files:
        ```python
        # /// script
        # requires-python = ">=3.12"
        # dependencies = [
        #   "requests<3",
        #   "rich",
        # ]
        # ///
        ```
        Add deps to an existing inline script with
        `uv add --script script.py 'requests<3'` (uv edits the block for you).
        For a self-executing script, use the shebang `#!/usr/bin/env -S uv run --script`.
      - Do not use `pip install`, `pip3 install`, or `uv add` for standalone scripts. Inline the dependencies instead.
      - For Python projects (not standalone scripts), use `uv init`, `uv add`, and `uv run`.
      - Use `uv run` to execute any Python tooling (pytest, ruff, mypy, etc.).

      # Nix dev environments

      - Most projects here are Nix flakes. When the project root has a `flake.nix`
        with a `devShell`, shell commands need that dev shell's tools.
      - Treat the env as already active when `$IN_NIX_SHELL` or `$DIRENV_DIR` is
        set (the usual case — the session is launched from a direnv-loaded
        shell); run commands normally.
      - When neither is set and a command fails with a missing tool, re-run it in
        the dev shell instead of installing anything globally:
        `nix develop -c '<command>'`. Each command runs in a fresh shell, so wrap
        every command — entering the shell once does not persist.
      - When a `flake.nix` devShell exists but there is no `.envrc`, suggest
        adding one containing `use flake` (then `direnv allow`) so it loads
        automatically — but do not create or commit the file.
    '';
    # Hard enforcement: execpolicy rules that block these commands outright.
    # decision values are allow | prompt | forbidden (strictest wins);
    # written to CODEX_HOME/rules/deny-python.rules.
    rules.deny-python = ''
      prefix_rule(pattern = ["python"], decision = "forbidden", justification = "Use uv run instead of python directly")
      prefix_rule(pattern = ["python3"], decision = "forbidden", justification = "Use uv run instead of python3 directly")
      prefix_rule(pattern = ["pip"], decision = "forbidden", justification = "Use uv for dependency management")
      prefix_rule(pattern = ["pip3"], decision = "forbidden", justification = "Use uv for dependency management")
      prefix_rule(pattern = ["uv", "pip"], decision = "forbidden", justification = "Use uv add or inline script metadata instead")
    '';
  };
}
