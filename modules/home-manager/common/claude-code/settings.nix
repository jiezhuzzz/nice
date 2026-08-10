# Claude Code itself: package, config location, and every settings key not
# owned by a sibling (hooks/ owns settings.hooks, statusline.nix owns
# settings.statusLine — the same leaf in two files is an eval error).
{
  config,
  inputs,
  pkgs,
  ...
}: let
  # claude-code from llm-agents.nix (upstream tracks it faster than nixpkgs).
  # A prebuilt per-platform binary, so this resolves per host via the system.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in {
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
      # under ~/.config/claude/projects/<project>/memory/. CLAUDE.md and the
      # `context` in context.nix still apply (those are user-authored, not auto
      # memory).
      autoMemoryEnabled = false;
      # Backstops for the guards in hooks/: the hooks run first and refuse
      # with the corrected command; these deny rules only surface if a hook
      # fails open (a hook that errors is non-blocking). One entry set per
      # guard file — keep them in step.
      permissions = {
        defaultMode = "auto";
        deny = [
          # hooks/uv-only.nix
          "Bash(python *)"
          "Bash(python3 *)"
          "Bash(pip *)"
          "Bash(pip3 *)"
          "Bash(uv pip *)"
          # hooks/nix-declarative.nix
          "Bash(nix-env -i*)"
          "Bash(nix-env --install*)"
          "Bash(nix profile install*)"
          "Bash(nix profile add*)"
          # hooks/flake-lock.nix
          "Edit(**/flake.lock)"
          "Write(**/flake.lock)"
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
      attribution = {
        commit = "";
        pr = "";
      };
      disableAgentView = true;
    };
  };
}
