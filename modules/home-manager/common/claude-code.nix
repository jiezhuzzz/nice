{
  config,
  pkgs,
  ...
}: let
  claude-plugins-official = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "1a2f18b05cf5652fd25403e8d229fc884fb84103";
    sha256 = "2e332eb2e7eff87f3eb763bd0c98114bd40eb877a57a9216b9616a88ae72dd44";
  };
  codex-plugin-cc = pkgs.fetchFromGitHub {
    owner = "openai";
    repo = "codex-plugin-cc";
    rev = "v1.0.4";
    sha256 = "cd675dcf5f1cdc4d794cfb84be3324064af088594add9a881b960fe715fa6482";
  };
  ast-grep-skill = pkgs.fetchFromGitHub {
    owner = "ast-grep";
    repo = "agent-skill";
    rev = "577f4d4507678f2c8cee150fae25e6ce309f70b1";
    sha256 = "2e0185b4f89ec8ab68aeedb60211d6f21be427c9021ced82afcac13961aec6f6";
  };
  statusline = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)
    jq() { ${pkgs.jq}/bin/jq "$@"; }
    git() { ${pkgs.git}/bin/git "$@"; }

    MODEL=$(printf '%s' "$input" | jq -r '.model.display_name')
    EFFORT=$(printf '%s' "$input" | jq -r '.effort.level // empty')
    DIR=$(printf '%s' "$input" | jq -r '.workspace.current_dir')
    WORKTREE=$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty')
    PCT=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
    RL_5H=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' | cut -d. -f1)
    RL_7D=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | cut -d. -f1)
    COST=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
    DURATION_MS=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')

    CYAN=$'\033[36m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    RED=$'\033[31m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'

    ICON_DIR=$''
    ICON_BRANCH=$'\xee\x9c\xa5'
    ICON_WORKTREE=$'\xee\x97\xbb'
    ICON_CLOCK=$''

    CTX_LEFT=$((100 - PCT))
    if [ "$CTX_LEFT" -le 10 ]; then BAR_COLOR="$RED"
    elif [ "$CTX_LEFT" -le 30 ]; then BAR_COLOR="$YELLOW"
    else BAR_COLOR="$GREEN"; fi

    FILLED=$((CTX_LEFT / 20))
    EMPTY=$((5 - FILLED))
    BAR=""
    [ "$FILLED" -gt 0 ] && printf -v FILL "%''${FILLED}s" && BAR="''${FILL// /█}"
    [ "$EMPTY" -gt 0 ] && printf -v PAD "%''${EMPTY}s" && BAR="$BAR''${PAD// /░}"

    TOTAL_S=$((DURATION_MS / 1000))
    DAYS=$((TOTAL_S / 86400))
    HOURS=$(((TOTAL_S % 86400) / 3600))
    MINS=$(((TOTAL_S % 3600) / 60))
    SECS=$((TOTAL_S % 60))
    if [ "$DAYS" -gt 0 ]; then TIME_FMT="''${DAYS}d ''${HOURS}h ''${MINS}m ''${SECS}s"
    elif [ "$HOURS" -gt 0 ]; then TIME_FMT="''${HOURS}h ''${MINS}m ''${SECS}s"
    else TIME_FMT="''${MINS}m ''${SECS}s"; fi
    COST_FMT=$(printf '$%.2f' "$COST")

    BRANCH=""
    if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
      B=$(git -C "$DIR" branch --show-current 2>/dev/null)
      [ -n "$B" ] && BRANCH=" | $ICON_BRANCH $B"
    fi
    [ -n "$WORKTREE" ] && BRANCH="$BRANCH | $ICON_WORKTREE $WORKTREE"

    EFFORT_TAG=""
    [ -n "$EFFORT" ] && EFFORT_TAG=" ''${DIM}($EFFORT)''${RESET}"

    LIMITS=""
    if [ -n "$RL_5H" ] || [ -n "$RL_7D" ]; then
      RL_MIN_LEFT=100
      if [ -n "$RL_5H" ]; then
        RL_5H_LEFT=$((100 - RL_5H))
        [ "$RL_5H_LEFT" -lt "$RL_MIN_LEFT" ] && RL_MIN_LEFT=$RL_5H_LEFT
      fi
      if [ -n "$RL_7D" ]; then
        RL_7D_LEFT=$((100 - RL_7D))
        [ "$RL_7D_LEFT" -lt "$RL_MIN_LEFT" ] && RL_MIN_LEFT=$RL_7D_LEFT
      fi
      if [ "$RL_MIN_LEFT" -le 10 ]; then RL_COLOR="$RED"
      elif [ "$RL_MIN_LEFT" -le 30 ]; then RL_COLOR="$YELLOW"
      else RL_COLOR="$GREEN"; fi
      LIMITS_TXT=""
      [ -n "$RL_5H" ] && LIMITS_TXT="5h:$RL_5H_LEFT%"
      [ -n "$RL_7D" ] && LIMITS_TXT="''${LIMITS_TXT:+$LIMITS_TXT }7d:$RL_7D_LEFT%"
      LIMITS=" | ''${RL_COLOR}''${LIMITS_TXT} left''${RESET}"
    fi

    printf '%s\n' "''${CYAN}[$MODEL]''${RESET}$EFFORT_TAG $ICON_DIR ''${DIR##*/}$BRANCH | ''${BAR_COLOR}$BAR''${RESET} $CTX_LEFT% left$LIMITS | ''${YELLOW}$COST_FMT''${RESET} | $ICON_CLOCK ''${TIME_FMT}"
  '';
in {
  programs.claude-code = {
    enable = true;
    configDir = "${config.xdg.configHome}/claude";
    skills = ../../../agents/skills;
    settings = {
      model = "opus[1m]";
      # effortLevel = "xhigh";
      # Disable auto memory: stop Claude from writing/updating its own notes
      # under ~/.config/claude/projects/<project>/memory/. CLAUDE.md and
      # `context` below still apply (those are user-authored, not auto memory).
      autoMemoryEnabled = false;
      permissions = {
        defaultMode = "auto";
        deny = [
          "Bash(python *)"
          "Bash(python3 *)"
          "Bash(pip *)"
          "Bash(pip3 *)"
          "Bash(uv pip *)"
        ];
      };
      skipDangerousModePermissionPrompt = true;
      env = {
        # Force effort via env, not just effortLevel: Claude Code "pins" each new
        # Opus version to its built-in launch effort (opus-4-8 defaults to "high")
        # and ignores the persisted effortLevel until effort is changed interactively
        # once — which never happens here because settings.json is a read-only Nix
        # symlink (/effort writes fail with EACCES). The env var bypasses the pin.
        CLAUDE_CODE_EFFORT_LEVEL = "xhigh";
        CLAUDE_CODE_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/claude/plugins";
        CLAUDE_CODE_DEBUG_LOGS_DIR = "${config.xdg.stateHome}/claude/logs";
        CLAUDE_CODE_TMPDIR = "/tmp/claude-code-${config.home.username}";
      };
      theme = "auto";
      tui = "fullscreen";
      statusLine = {
        type = "command";
        command = "${statusline}";
      };
      attribution = {
        commit = "";
        pr = "";
      };
    };
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
    plugins = [
      (pkgs.fetchFromGitHub {
        owner = "obra";
        repo = "superpowers";
        rev = "v5.1.0";
        sha256 = "dc4deb3ba851f3b2547d2dd757511aa33e920d639fb65796bcdf543cd144323c";
        name = "superpowers";
      })
      "${claude-plugins-official}/plugins/skill-creator"
      "${claude-plugins-official}/plugins/code-review"
      "${claude-plugins-official}/plugins/claude-code-setup"
      "${claude-plugins-official}/plugins/code-simplifier"
      "${claude-plugins-official}/plugins/ralph-loop"
      "${codex-plugin-cc}/plugins/codex"
      "${ast-grep-skill}/ast-grep"
      ../../../agents/plugins/research-writing
    ];
  };
}
