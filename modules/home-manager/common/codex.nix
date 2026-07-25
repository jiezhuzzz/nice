{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  # codex from llm-agents.nix (upstream tracks it faster than nixpkgs), built
  # from source per host so the trust patch below can be layered on.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # Codex now rejects legacy `[profiles.<name>]` tables inside config.toml;
  # each profile must be its own CODEX_HOME/<name>.config.toml using top-level
  # keys (no `[profiles.x]` wrapper), overlaid on the base config when invoked
  # with `--profile <name>`. See
  # https://developers.openai.com/codex/config-advanced#profiles.
  #
  # Self-contained `api` profile: route Codex at OpenAI's US-region endpoint
  # and authenticate with an API key from $OPENAI_API_KEY (a custom
  # `model_providers` entry — ModelProviderInfo in config.schema.json — since
  # there is no `openai_base_url` key) instead of the ChatGPT subscription
  # login. Activate with `codex --profile api`.
  apiProfile = (pkgs.formats.toml {}).generate "codex-api.config.toml" {
    model_provider = "openai-us";
    model_providers.openai-us = {
      name = "OpenAI (US API)";
      base_url = "https://us.api.openai.com/v1";
      env_key = "OPENAI_API_KEY";
      wire_api = "responses";
    };
  };

  # Mirror the upstream home-manager codex module's path math (modules/programs/
  # codex.nix) so this profile lands in the same CODEX_HOME as the generated
  # config.toml on both XDG (preferXdgDirectories) and plain ~/.codex hosts.
  xdgConfigHome = lib.removePrefix config.home.homeDirectory config.xdg.configHome;
  codexConfigDir =
    if config.home.preferXdgDirectories
    then "${xdgConfigHome}/codex"
    else ".codex";
in {
  programs.codex = {
    enable = true;
    # Patch Codex so project-trust lookup walks up ancestor paths instead of
    # requiring an exact directory match. Upstream only trusts the literal
    # path in `[projects."<dir>"]`, so pre-trusting $HOME below does NOT cover
    # subdirectories — opening Codex in any repo under $HOME still shows the
    # "Do you trust the contents of this directory?" prompt every time. With
    # this patch, trusting $HOME recursively trusts everything beneath it.
    # See https://github.com/openai/codex/issues/14601 (workaround comment).
    # Verified to apply against codex 0.145.0 (tag rust-v0.145.0), the version
    # llm-agents currently ships; revisit if the patchPhase fails after a bump.
    package = llmAgents.codex.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./recursive-project-trust.patch];
    });
    skills = {
      # Conventional Commits + Conventional Branch enforcement, sourced from
      # this repo so Claude Code and Codex share one skill definition.
      # Symlinked into Codex's skills dir (~/.agents/skills/ on Codex >=
      # 0.94.0, else ~/.config/codex/skills/).
      conventional-git = ../../../agents/skills/conventional-git;
    };
    settings = {
      # Auto-review: route approval requests to Codex's Guardian reviewer
      # agent instead of pausing for the user. Only takes effect with
      # approval_policy = "on-request" (no requests to review under "never").
      approval_policy = "on-request";
      approvals_reviewer = "auto_review";
      sandbox_mode = "workspace-write";

      # Pre-trust the home directory so Codex never persists trust at runtime.
      # config.toml is a read-only nix-store symlink, so when Codex hits an
      # untrusted dir and tries to write `[projects."<dir>"] trust_level`, the
      # config/batchWrite fails (the TUI hides the real cause — openai/codex
      # #25008). Declaring it here means the dir is already trusted, so no write
      # is attempted. Path is per-host via config.home.homeDirectory.
      #
      # Combined with the recursive-project-trust patch on `package` above, this
      # single entry trusts every directory beneath $HOME (ancestor-path
      # lookup), so the trust prompt no longer appears in any repo under $HOME.
      projects.${config.home.homeDirectory}.trust_level = "trusted";

      # Remote MCP server (streamable HTTP). Renders to
      # CODEX_HOME/config.toml as `[mcp_servers.notion]` with a `url` key,
      # which Codex treats as a streamable-HTTP transport.
      mcp_servers.notion.url = "https://mcp.notion.com/mcp";

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
      model_reasoning_effort = "high";
      # model = "gpt-5.5";
      #
      # The US-region API profile is intentionally NOT defined here: Codex
      # rejects legacy `[profiles.<name>]` tables in config.toml. It lives in
      # its own CODEX_HOME/api.config.toml (see `apiProfile` and the
      # `home.file` entry below). Run it with `codex --profile api`.
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

  # New-style Codex profile (config.toml rejects `[profiles.x]` tables). Lands
  # next to the module-managed config.toml inside CODEX_HOME.
  home.file."${codexConfigDir}/api.config.toml".source = apiProfile;
}
