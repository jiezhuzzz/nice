{
  config,
  inputs,
  pkgs,
  ...
}: let
  # claude-code from llm-agents.nix (upstream tracks it faster than nixpkgs).
  # A prebuilt per-platform binary, so this resolves per host via the system.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Anthropic's marketplace, pinned in flake.lock (see flake.nix). One repo of
  # ~35 plugins; everything below is a subdirectory of it, so there is exactly
  # one thing to update.
  officialPlugins = "${inputs.claude-plugins-official}/plugins";

  # ccstatusline (also from llm-agents.nix) renders the status line from this
  # JSON, replacing the hand-rolled shell script that used to live here — which
  # forked jq nine times and git twice on every single render.
  #
  # Widgets read `rate_limits.five_hour` / `.seven_day` straight out of the
  # status payload, so the 5h/7d numbers cost no API call. One thing is lost
  # against the old script: ccstatusline has no value-driven colour, so nothing
  # turns amber or red as the context fills.
  seg = id: type: pair: extra:
    {
      inherit id type;
      color = pair.fg;
      backgroundColor = pair.bg;
    }
    // extra;

  # 月 "moonlight": powerline segments in dim, cold blue-violet with pale text
  # over them. Every boundary alternates dark against light as well as shifting
  # hue, which is what keeps neighbouring fills legible when the whole ramp
  # sits this close together.
  ccstatuslineSettings = {
    version = 3;
    colorLevel = 3; # truecolor
    defaultPadding = " ";
    defaultPaddingSide = "both";
    flexMode = "full";
    gitCacheTtlSeconds = 5;
    powerline = {
      enabled = true;
      # Nix strings have no \uXXXX escape, so the Nerd Font glyphs sit here as
      # literal characters: separator U+E0B0, caps U+E0B6 and U+E0B4.
      separators = [""];
      separatorInvertBackground = [false];
      startCaps = [""];
      endCaps = [""];
      theme = "custom"; # colours come from each segment below
      autoAlign = false;
      continueThemeAcrossLines = false;
    };
    lines = [
      [
        # Model and effort share one fill. `merge` drops the arrow that would
        # otherwise sit between them; it has to be the no-padding form, because
        # every widget is padded on both sides and a plain merge would leave a
        # double space — hence the explicit single space put back after it.
        (seg "model" "model" {
            fg = "hex:eef1ff";
            bg = "hex:4c5b8a";
          } {
            bold = true;
            rawValue = true;
            merge = "no-padding";
          })
        {
          id = "model-gap";
          type = "custom-text";
          customText = " ";
          backgroundColor = "hex:4c5b8a";
          merge = "no-padding";
        }
        (seg "effort" "thinking-effort" {
          fg = "hex:a3aed0";
          bg = "hex:4c5b8a";
        } {rawValue = true;})
        (seg "cwd" "current-working-dir" {
            fg = "hex:d6e2ff";
            bg = "hex:35507a";
          } {
            rawValue = true;
            metadata.segments = "1";
          })
        (seg "branch" "git-branch" {
            fg = "hex:e6f2ff";
            bg = "hex:4a7fa6";
          } {
            rawValue = true;
            metadata.hideNoGit = "true";
          })
        # Renders nothing outside a linked worktree, so it costs no width there.
        (seg "worktree" "worktree-name" {
          fg = "hex:d8f0f0";
          bg = "hex:2f6b74";
        } {rawValue = true;})
        (seg "ctx" "context-percentage" {
          fg = "hex:e4f6f5";
          bg = "hex:4f8a8b";
        } {metadata.inverse = "true";}) # percent remaining, not consumed
        (seg "session" "session-usage" {
          fg = "hex:d5e3f5";
          bg = "hex:2e4a6b";
        } {})
        (seg "weekly" "weekly-usage" {
          fg = "hex:eef2ff";
          bg = "hex:6b7fa8";
        } {})
        # The one inverted segment: dark text on a light fill.
        (seg "cost" "session-cost" {
            fg = "hex:131a28";
            bg = "hex:c3cfe8";
          } {
            bold = true;
            rawValue = true;
          })
        # A step down from the cost, but neutral grey — a second periwinkle
        # here would echo the weekly two segments back.
        (seg "clock" "session-clock" {
          fg = "hex:1a2130";
          bg = "hex:a2a9b5";
        } {rawValue = true;})
      ]
    ];
  };
in {
  # On PATH so `ccstatusline` opens its TUI. Editing there is read-only: the
  # settings file below is a store symlink, so saves fail — it is a preview of
  # what this module declares, not a way to change it.
  home.packages = [llmAgents.ccstatusline];

  # ccstatusline reads ~/.config/ccstatusline/settings.json. Generating it keeps
  # the status line declarative like everything else. A read-only store path is
  # safe on the render path: ccstatusline only writes back when an
  # `updatemessage` key is present, which a generated config never has, and its
  # git/timer caches go to ~/.cache/ccstatusline regardless.
  xdg.configFile."ccstatusline/settings.json".source =
    (pkgs.formats.json {}).generate "ccstatusline-settings.json" ccstatuslineSettings;

  programs.claude-code = {
    enable = true;
    package = llmAgents.claude-code;
    configDir = "${config.xdg.configHome}/claude";
    settings = {
      model = "opus[1m]";
      # Default thinking/reasoning effort. Persisted here, but see the
      # CLAUDE_CODE_EFFORT_LEVEL note under `env` — on its own this key loses to
      # the per-model launch-effort pin, so both are set.
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
        command = "${llmAgents.ccstatusline}/bin/ccstatusline";
        padding = 0;
        # Re-render between turns so the session clock stays live. Claude Code
        # honours this from 2.1.97 on.
        refreshInterval = 10;
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
    # Each entry is linked whole as ~/.config/claude/skills/<name> and loaded as
    # a personal plugin, so its skills, agents, commands and hooks all register
    # — namespaced under the attribute name. An attribute set rather than a
    # list: the name becomes that directory, where the list form derives it from
    # the store path and yields churn like `bxa1s0m3h4sh-source`.
    #
    # Anything else from the marketplace is a one-liner away; `ls
    # ${officialPlugins}` lists all ~35.
    plugins = {
      claude-code-setup = "${officialPlugins}/claude-code-setup";
      code-simplifier = "${officialPlugins}/code-simplifier";
      feature-dev = "${officialPlugins}/feature-dev";
    };
  };
}
