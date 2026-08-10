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
  # A bare `permissions.deny` entry tells the agent only that something was
  # refused, never what to do instead — so it improvises, and the usual
  # improvisation is to rewrite the job in shell rather than to reach for the
  # tool that was actually wanted. Each guard below denies the same commands but
  # hands back the corrected command line, which is the part that redirects it.
  # Verified against claude-code 2.1.222: a PreToolUse hook is consulted before
  # the permission rules, so this reason is what the model sees, and
  # `permissions.deny` stays on purely as a backstop for a script failing open.
  #
  # Deliberately `command` hooks, not `prompt` ones: they run on every single
  # tool call, so they must be free and instant, and none of these questions
  # needs judgement. Deliberately not rewriting hooks either (PreToolUse can
  # silently swap the command via updatedInput) — a rewrite leaves the agent
  # reading output from a command it did not write, which is its own debugging
  # trap. Refusing and naming the fix keeps its picture of the shell honest.
  #
  # The wire format is identical for all of them, so it lives here once. Note
  # that silence means "allow": any guard that errors fails open, which is the
  # reason the coarse `permissions.deny` list is kept alongside these.
  mkGuardHook = name: text:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.jq];
      text =
        ''
          input=$(cat)

          deny() {
            jq -nc --arg reason "$1" \
              '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
            exit 0
          }
        ''
        + text;
    };

  # Prepended by the guards that read a command line rather than a file path.
  # `sep` matches a word only in *command position*: start of the line, or after
  # a ; & | or ( separator. This is what stops a guard tripping over its own
  # advice — in `uv run python -c ...` and in `nix develop -c python x.py` the
  # word `python` follows an ordinary argument rather than a separator, so
  # neither matches.
  commandGuardPreamble = ''
    cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
    sep='(^|[;&|(])[[:space:]]*'
  '';

  uvOnlyHook = mkGuardHook "claude-uv-only-hook" (
    commandGuardPreamble
    + ''
      if [[ "$cmd" =~ $sep(uv[[:space:]]+pip|pip3?)([[:space:]]|$) ]]; then
        deny "Installing with pip is not how this machine does Python. For a standalone script, declare dependencies inline with PEP 723 script metadata and run it with 'uv run script.py' — 'uv add --script script.py <pkg>' edits that block for you. Inside a project, use 'uv add <pkg>'. Do not fall back to writing the task in shell instead; uv is installed and is the supported path."
      fi

      if [[ "$cmd" =~ $sep(python3?)([[:space:]]|$) ]]; then
        # `python -c` / `-m` / `--version` keep the interpreter and gain a `uv
        # run` prefix; `python script.py` drops it, since uv picks the
        # interpreter itself from the script's own metadata.
        if [[ "$cmd" =~ $sep(python3?)[[:space:]]+- ]]; then
          suggestion=$(sed -E "s@(^|[;&|(][[:space:]]*)python3?[[:space:]]@\1uv run python @g" <<<"$cmd")
        else
          suggestion=$(sed -E "s@(^|[;&|(][[:space:]]*)python3?[[:space:]]@\1uv run @g" <<<"$cmd")
        fi
        deny "Run Python through uv, never a bare interpreter. Use this instead: $suggestion — if it needs third-party packages, declare them inline with PEP 723 first ('uv add --script <script> <pkg>'). Do not work around this by rewriting the task in shell, awk or a heredoc; uv is installed and is the supported path."
      fi
    ''
  );

  # The Nix counterpart of the pip rule, and it exists for the same reason: an
  # imperative install is the one thing that puts software on this machine
  # without a line in this flake describing it. It also hides — nothing in a
  # `git status` shows that `nix-env -i` ever ran, so the drift is only found
  # much later, on a host that was supposed to be reproducible.
  #
  # The corrected command depends on why the tool is wanted, so the reason names
  # both: `nix shell nixpkgs#pkg -c ...` for a one-off (the common case — the
  # tool is needed for the next command and never again), or a module edit plus
  # a rebuild when it should persist.
  nixDeclarativeHook = mkGuardHook "claude-nix-declarative-hook" (
    commandGuardPreamble
    + ''
      # nix-env is only imperative when it installs; `nix-env -q`, for instance,
      # just queries and is harmless, so the install flags are matched too.
      if [[ "$cmd" =~ $sep"nix-env"[[:space:]] ]] && [[ "$cmd" =~ [[:space:]](-i|-iA|-ie|--install)([[:space:]]|$) ]]; then
        deny "nix-env installs imperatively, which this machine does not do — nothing in the NICE flake would record that the package exists. If the tool is needed for one command, run it ephemerally: 'nix shell nixpkgs#<pkg> -c <command>'. If it should persist, add it to the right module (home.packages, or environment.systemPackages for a system tool) and rebuild. Do not substitute curl-pipe-sh or a download into ~/.local/bin either."
      fi

      if [[ "$cmd" =~ $sep"nix"[[:space:]]+profile[[:space:]]+(add|install)([[:space:]]|$) ]]; then
        deny "'nix profile' installs imperatively, which this machine does not do — nothing in the NICE flake would record that the package exists. If the tool is needed for one command, run it ephemerally: 'nix shell nixpkgs#<pkg> -c <command>'. If it should persist, add it to the right module (home.packages, or environment.systemPackages for a system tool) and rebuild."
      fi
    ''
  );

  # flake.lock is generated, and hand-editing it is worse than useless: every
  # entry carries a narHash, so an edited revision either fails to verify or
  # silently pins something that was never fetched. The agent reaches for it
  # because a lock file *looks* like editable JSON, which is exactly why the
  # refusal has to name the regenerating command.
  #
  # This one matches on Edit|Write rather than Bash, so it reads file_path
  # instead of a command line.
  flakeLockHook = mkGuardHook "claude-flake-lock-hook" ''
    path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

    case "$path" in
      */flake.lock | flake.lock)
        deny "flake.lock is generated — never edit it by hand, since each entry carries a narHash that will no longer match. Regenerate it instead: 'nix flake update' rewrites every input, 'nix flake update <input>' bumps just one (for example 'nix flake update nixpkgs'). To change where an input points, edit the inputs block in flake.nix and let the lock follow."
        ;;
    esac
  '';
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
      # Compact against a 400k window rather than the model's real 1M — frequent
      # cheap compactions instead of one enormous one. Only live while
      # auto-compact is on; disabling that reverts to the full model window.
      autoCompactWindow = 400000;
      # Disable auto memory: stop Claude from writing/updating its own notes
      # under ~/.config/claude/projects/<project>/memory/. CLAUDE.md and
      # `context` below still apply (those are user-authored, not auto memory).
      autoMemoryEnabled = false;
      # The uv-only rule is enforced twice, and the order matters. The hook runs
      # first and is the one the agent actually reads — it refuses *and* prints
      # the uv command to run instead. These deny rules only ever surface if the
      # hook fails open (missing jq, a shell error), since a hook that errors is
      # non-blocking; they refuse without explaining, which is exactly the
      # behaviour the hook exists to replace.
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
      # Hooks matching the same tool run in parallel and cannot see each other,
      # so each guard has to stand alone — the first one to deny wins, and the
      # rest are wasted work rather than a conflict.
      hooks.PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${uvOnlyHook}/bin/claude-uv-only-hook";
              timeout = 5;
            }
            {
              type = "command";
              command = "${nixDeclarativeHook}/bin/claude-nix-declarative-hook";
              timeout = 5;
            }
          ];
        }
        {
          matcher = "Edit|Write";
          hooks = [
            {
              type = "command";
              command = "${flakeLockHook}/bin/claude-flake-lock-hook";
              timeout = 5;
            }
          ];
        }
      ];
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

      # Line wrapping

      - Never hand-wrap text to a column width. Layout is the formatter's job, not something to do by hand.
      - Markdown: write each paragraph and each bullet as one line, however long, and let the editor soft-wrap it. Never insert a line break mid-sentence or at ~80 characters. Tables and fenced code blocks are content rather than prose — leave those laid out as written.
      - Code: never break a line just to hit a width, and never pad with spaces to align things into columns. Write it plainly and run the project's formatter — `nix fmt` (alejandra) here, otherwise whatever the repo configures: prettier, `ruff format`, `rustfmt`, `gofmt`.
      - The one exception is text no formatter reflows: comments and docstrings. Match the file being edited — where its comments wrap at ~80 columns, keep wrapping to match, since nothing will do it afterwards.

      # Nix dev environments

      - Most projects here are Nix flakes. When the project root has a `flake.nix` with a `devShell`, some commands need that dev shell's tools.
      - Do not assume the dev shell is active. It is active only when `$IN_NIX_SHELL` or `$DIRENV_DIR` is set, and several of these repos have no `.envrc` — a plain session then starts *outside* the dev shell, with its tools simply absent from `PATH`. Check rather than guess.
      - When a tool is missing, choose by where it lives. Listed in this project's `devShell`: `nix develop -c '<command>'`. Not listed there, which is the usual case for one-off utilities like `rg`, `strings` or `hexdump`: `nix shell nixpkgs#<package> -c '<command>'`, or `nix run nixpkgs#<package> -- <args>` when the package's own binary is all that is wanted. Each runs a fresh shell per invocation, so wrap every command — entering once does not persist.
      - Never install something to make a command work: no `nix-env -i`, no `nix profile add`, no `curl | sh`, no dropping a binary in `~/.local/bin`. A tool needed permanently belongs in a module in the NICE flake; everything else is ephemeral through `nix shell`.
      - `nix fmt` is the formatter for a flake that defines one, and it needs no dev shell — the flake supplies its own. In NICE it runs treefmt (alejandra, statix, shellcheck, shfmt, actionlint) across the tree.
      - `flake.lock` is generated. Never hand-edit it: regenerate with `nix flake update` for every input, or `nix flake update <input>` for one.
      - When a `flake.nix` devShell exists but there is no `.envrc`, suggest adding one containing `use flake` (then `direnv allow`) so it loads automatically — but do not create or commit the file.
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
