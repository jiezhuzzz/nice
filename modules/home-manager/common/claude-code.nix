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

    if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
    elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
    else BAR_COLOR="$GREEN"; fi

    FILLED=$((PCT / 20))
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
      RL_MAX=0
      [ -n "$RL_5H" ] && [ "$RL_5H" -gt "$RL_MAX" ] && RL_MAX=$RL_5H
      [ -n "$RL_7D" ] && [ "$RL_7D" -gt "$RL_MAX" ] && RL_MAX=$RL_7D
      if [ "$RL_MAX" -ge 90 ]; then RL_COLOR="$RED"
      elif [ "$RL_MAX" -ge 70 ]; then RL_COLOR="$YELLOW"
      else RL_COLOR="$GREEN"; fi
      LIMITS_TXT=""
      [ -n "$RL_5H" ] && LIMITS_TXT="5h:$RL_5H%"
      [ -n "$RL_7D" ] && LIMITS_TXT="''${LIMITS_TXT:+$LIMITS_TXT }7d:$RL_7D%"
      LIMITS=" | ''${RL_COLOR}''${LIMITS_TXT}''${RESET}"
    fi

    printf '%s\n' "''${CYAN}[$MODEL]''${RESET}$EFFORT_TAG $ICON_DIR ''${DIR##*/}$BRANCH | ''${BAR_COLOR}$BAR''${RESET} $PCT%$LIMITS | ''${YELLOW}$COST_FMT''${RESET} | $ICON_CLOCK ''${TIME_FMT}"
  '';
in {
  programs.claude-code = {
    enable = true;
    configDir = "${config.xdg.configHome}/claude";
    skills = ../../../agents/skills;
    settings = {
      model = "claude-opus-4-7[1m]";
      effortLevel = "xhigh";
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
        CLAUDE_CODE_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/claude/plugins";
        CLAUDE_CODE_DEBUG_LOGS_DIR = "${config.xdg.stateHome}/claude/logs";
        CLAUDE_CODE_TMPDIR = "/tmp/claude-code-${config.home.username}";
      };
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
