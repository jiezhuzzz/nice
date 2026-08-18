{
  config,
  inputs,
  pkgs,
  ...
}: let
  # pi from llm-agents.nix (upstream tracks it faster than nixpkgs: 0.83.0 vs
  # nixpkgs' 0.82.1), matching how claude-code and codex are sourced here.
  # A prebuilt per-platform binary, so this resolves per host via the system.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # Directory of catppuccin-{latte,frappe,macchiato,mocha}.json.
  piThemes = "${inputs.pi-catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/pi/themes";
in {
  # pi is a terminal coding agent with multi-model support
  # (https://github.com/earendil-works/pi).
  programs.pi-coding-agent = {
    enable = true;
    # The upstream module's default is pkgs.pi-coding-agent; llm-agents names
    # the same program `pi`.
    package = llmAgents.pi;
    # XDG instead of pi's upstream ~/.pi/agent default. settings.json,
    # keybindings.json, models.json and AGENTS.md render here, and the module
    # exports PI_CODING_AGENT_DIR automatically because this differs from the
    # upstream default, so the CLI reads the same location.
    configDir = "${config.xdg.configHome}/pi/agent";
    settings = {
      # defaultModel only takes effect alongside defaultProvider — pi requires
      # both before it will look the model up, and otherwise falls back to its
      # built-in per-provider table.
      defaultProvider = "deepseek";
      defaultModel = "deepseek-v4-flash";
      defaultThinkingLevel = "xhigh";
      quietStartup = true;
      # Per-level token budgets are left at upstream's values (thinkingBudgets omitted).
      hideThinkingBlock = false;

      # Extensions/skills, declared rather than installed. `pi install` cannot
      # work here: it records the package by writing settings.json, which is a
      # read-only store symlink — pi swallows the failure, prints "Installed"
      # and exits 0, and `pi list` then shows nothing. Listing them here instead
      # means the declaration is already present, so on startup pi only has to
      # fetch what is missing into <configDir>/npm/ (a real, writable dir).
      # nodejs and bun come from programs.{npm,bun}, so the fetch has a runtime.
      #
      # Left unpinned on purpose: every one of these binds to pi's own
      # @earendil-works/* API, so they need to move when pi does, and a pinned
      # spec is skipped by `pi update --extensions`. The cost is that the code
      # is fetched from npm at runtime and is not part of any store closure —
      # append @<version> to freeze one if that ever matters more.
      #
      # The rpiv-* family (github.com/juicesharp/rpiv-mono) is lockstep-versioned
      # upstream, so unpinned `latest` keeps every sibling on the same version.
      # Declared directly here instead of via /rpiv-setup, which installs by
      # rewriting settings.json (read-only store symlink, same trap as `pi install`).
      #
      # NOTE: these run with full system access (pi's own warning) — extensions
      # execute arbitrary code and skills can direct the model to run anything.
      packages = [
        "npm:context-mode" # sandboxed code execution to shrink context use
        "npm:pi-lens" # real-time LSP feedback on edits
        "npm:pi-mcp-adapter" # load MCP servers as pi tools

        # rpiv-* standalone tools (github.com/juicesharp/rpiv-mono), installed
        # individually instead of the full rpiv-pi pipeline. Their only shared
        # dependency is @juicesharp/rpiv-config, which npm pulls in automatically
        # (a library, not a pi extension — nothing to declare here).
        "npm:@juicesharp/rpiv-workflow" # /wf runner — chain skills into typed multi-stage pipelines
        "npm:@juicesharp/rpiv-args" # $1/$ARGUMENTS placeholders + !`cmd` substitution in skills
        "npm:@juicesharp/rpiv-ask-user-question" # structured questionnaire to the user
        "npm:@juicesharp/rpiv-todo" # live task overlay surviving /reload
        "npm:@juicesharp/rpiv-advisor" # escalate to a stronger reviewer model
        "npm:@juicesharp/rpiv-web-tools" # web_search + web_fetch (replaces pi-web-access)
        # @tintinweb/pi-subagents replaces nicobailon's pi-subagents (superseded;
        # rpiv's /rpiv-setup actively prunes the old one). Supplies the Agent /
        # get_subagent_result / steer_subagent tools used by skills and advisors.
        "npm:@tintinweb/pi-subagents" # delegate tasks to subagents

        "npm:pi-powerline-footer" # powerline-style status footer
      ];

      # Catppuccin. pi only ships `dark` and `light` built in, and catppuccin/
      # nix has no pi module for autoEnable to pick up, so the theme comes from
      # the pi-catppuccin flake input instead. `themes` takes paths or
      # directories, so point it straight at the store dir — no copying into
      # configDir — and select the flavor set globally in theme.nix.
      themes = [piThemes];
      theme = "catppuccin-${config.catppuccin.flavor}";
    };
    # keybindings/models/context left at upstream defaults (unset).
  };

  # configDir is also where pi keeps its runtime state — sessions, auth.json,
  # trust.json, installed npm/git packages — none of which belongs in
  # $XDG_CONFIG_HOME. Sessions are the bulk of it and the only part with its own
  # override, so point them at $XDG_STATE_HOME; the rest is small and stays
  # alongside the config.
  home.sessionVariables.PI_CODING_AGENT_SESSION_DIR = "${config.xdg.stateHome}/pi/sessions";
}
