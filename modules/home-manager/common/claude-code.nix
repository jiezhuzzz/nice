{
  config,
  inputs,
  pkgs,
  ...
}: let
  # claude-code from llm-agents.nix (upstream tracks it faster than nixpkgs).
  # A prebuilt per-platform binary, so this resolves per host via the system.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  claude-plugins-official = pkgs.fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = "66799ffb4611b7e0c3af391c7569823a4d6b4246";
    sha256 = "39d0315d39d3537710efacf8b2f95ccb1c8b6b453eb8c14ba6c5221497f6a5f0";
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
  # Matt Pocock's skills, packaged as a plugin whose manifest sits at the repo
  # root (marketplace.json source "./"), so the plugin path is the store root.
  # Imperative equivalent: claude plugin marketplace add mattpocock/skills
  #                        claude plugin install mattpocock-skills@mattpocock
  mattpocock-skills = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "9603c1cc8118d08bc1b3bf34cf714f62178dea3b";
    sha256 = "4baa4044af7da061928ba5dd166eb360a1d3e208ce08dd3020f645725d614441";
  };
  # feature-dev and the local conventional-git plugin are command/agent plugins
  # with no SKILL.md, so the `plugins` (skills-dir) mechanism can't surface
  # their commands. Merge their commands/ dirs into one tree for commandsDir (a
  # single-directory option).
  #
  # commit-commands is deliberately absent: agents/plugins/conventional-git
  # supersedes it. Its clean_gone.md is carried over verbatim, its commit.md is
  # replaced by a subagent-delegating version, and symlinkJoin resolves
  # duplicate basenames first-path-wins — so keeping both would silently shadow
  # one of the two `commit.md`s. Only commit-push-pr.md is dropped outright;
  # the local plugin commits but never pushes.
  claude-commands = pkgs.symlinkJoin {
    name = "claude-commands";
    paths = [
      "${claude-plugins-official}/plugins/feature-dev/commands"
      ../../../agents/plugins/conventional-git/commands
    ];
  };
  # Same single-directory constraint for agentsDir, and the module asserts
  # `agents` and `agentsDir` are mutually exclusive — so the local plugin's
  # agent gets joined with feature-dev's rather than declared inline. This is
  # what makes `subagent_type: conventional-git` resolvable for the /commit
  # command, which the skills-dir plugin mechanism could not do.
  claude-agents = pkgs.symlinkJoin {
    name = "claude-agents";
    paths = [
      "${claude-plugins-official}/plugins/feature-dev/agents"
      ../../../agents/plugins/conventional-git/agents
    ];
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
    package = llmAgents.claude-code;
    configDir = "${config.xdg.configHome}/claude";
    # skills = ../../../agents/skills;
    # Load the command/agent plugins natively (see the note in `plugins` below
    # for why they can't go through the skills-dir plugin mechanism). These link
    # into ~/.config/claude/{commands,agents}/, which Claude Code loads directly
    # — giving `/feature-dev` (+ its code-explorer / code-architect / code-
    # reviewer agents) and the local conventional-git plugin's `/commit`,
    # `/worktree`, `/clean_gone` (+ its conventional-git subagent).
    # Commands land unnamespaced here, so it is `/commit`, not
    # `/conventional-git:commit`.
    commandsDir = claude-commands;
    agentsDir = claude-agents;
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
        # CLAUDE_CODE_EFFORT_LEVEL = "xhigh";
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
      disableAgentView = true;
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
    # Attribute set rather than a list: the attribute name becomes the plugin's
    # directory name. Deriving it from a store path (as the list form does)
    # yields unstable names like `bxa1s0m3h4sh-source`.
    plugins = {
      # superpowers = pkgs.fetchFromGitHub {
      #   owner = "jiezhuzzz";
      #   repo = "superpowers";
      #   # feat/modern branch, pinned to a commit for reproducibility
      #   rev = "ebfb33ff491e3b7cb3ce257f99e00c0645ec8b17";
      #   sha256 = "20021101d89002e891a03ba4bd661ba5a0113bb99c2b30d919e2d10366d4565c";
      #   name = "superpowers";
      # };
      # skill-creator = "${claude-plugins-official}/plugins/skill-creator";
      claude-code-setup = "${claude-plugins-official}/plugins/claude-code-setup";
      code-simplifier = "${claude-plugins-official}/plugins/code-simplifier";
      # feature-dev and commit-commands are NOT loadable via `plugins`: that
      # mechanism links plugins into ~/.config/claude/skills/, which Claude Code
      # treats as a skills-only source (it registers a plugin's SKILL.md skills
      # but ignores its commands/ and agents/). Both ship commands (feature-dev
      # also agents) and no skill, so via `plugins` they contribute nothing and
      # their slash commands stay unknown. They are instead loaded natively
      # through commandsDir/agentsDir above.
      # ralph-loop = "${claude-plugins-official}/plugins/ralph-loop";
      # codex = "${codex-plugin-cc}/plugins/codex";
      mattpocock-skills = "${mattpocock-skills}";
      # ast-grep = "${ast-grep-skill}/ast-grep";
      # research-writing = ../../../agents/plugins/research-writing;
    };
  };
}
