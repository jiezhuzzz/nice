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
      # Compact against a 400k window rather than the model's real 1M — frequent
      # cheap compactions instead of one enormous one. Only live while
      # auto-compact is on; disabling that reverts to the full model window.
      autoCompactWindow = 400000;
      # Disable auto memory: stop Claude from writing/updating its own notes
      # under ~/.config/claude/projects/<project>/memory/. CLAUDE.md and the
      # `context` in context.nix still apply (those are user-authored, not auto
      # memory).
      autoMemoryEnabled = false;
      # Remote Control off unless asked for per session (/remote-control). Left
      # unset it is not simply off: the resolver falls back to the org policy
      # default and a server-side rollout gate, so an explicit false is the
      # only way to keep the bridge from starting on its own.
      remoteControlAtStartup = false;
      skillOverrides = {
        claude-api = "user-invocable-only";
      };
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
          # hooks/flake-lock.nix. Edit() alone — file rules match every editing
          # tool, so a Write() entry is redundant and warns at startup.
          "Edit(**/flake.lock)"
          # hooks/github-via-gh.nix. Exact hosts, mirroring the guard's list —
          # docs.github.com, github.blog and *.github.io stay fetchable.
          "WebFetch(domain:github.com)"
          "WebFetch(domain:www.github.com)"
          "WebFetch(domain:api.github.com)"
          "WebFetch(domain:gist.github.com)"
          "WebFetch(domain:codeload.github.com)"
          "WebFetch(domain:raw.githubusercontent.com)"
          "WebFetch(domain:gist.githubusercontent.com)"
          "WebFetch(domain:objects.githubusercontent.com)"
          "Bash(curl *github.com*)"
          "Bash(curl *githubusercontent.com*)"
          "Bash(wget *github.com*)"
          "Bash(wget *githubusercontent.com*)"
        ];
      };
      skipDangerousModePermissionPrompt = true;
      env = {
        # Effort comes from the env var rather than the `effortLevel` setting
        # key: Claude Code "pins" each new Opus version to its built-in launch
        # effort (opus-4-8 defaults to "high") and ignores the persisted
        # effortLevel until effort is changed interactively once — which never
        # happens here because settings.json is a read-only Nix symlink (/effort
        # writes fail with EACCES). The env var bypasses the pin.
        CLAUDE_CODE_EFFORT_LEVEL = "xhigh";
        CLAUDE_CODE_PLUGIN_CACHE_DIR = "${config.xdg.cacheHome}/claude/plugins";
        CLAUDE_CODE_DEBUG_LOGS_DIR = "${config.xdg.stateHome}/claude/logs";
        CLAUDE_CODE_TMPDIR = "/tmp/claude-code-${config.home.username}";
      };
      outputStyle = "Concise";
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
