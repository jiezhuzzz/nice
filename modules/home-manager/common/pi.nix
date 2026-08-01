{
  inputs,
  pkgs,
  ...
}: let
  # pi from llm-agents.nix (upstream tracks it faster than nixpkgs: 0.83.0 vs
  # nixpkgs' 0.82.1), matching how claude-code and codex are sourced here.
  # A prebuilt per-platform binary, so this resolves per host via the system.
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # pi: a terminal coding agent with multi-model support
  # (https://github.com/earendil-works/pi). Enabled on every host via
  # profiles/home/core.nix.
  programs.pi-coding-agent = {
    enable = true;
    # The upstream module's default is pkgs.pi-coding-agent; llm-agents names
    # the same program `pi`.
    package = llmAgents.pi;
    settings = {
      # Use the highest reasoning effort by default.
      defaultThinkingLevel = "high";
      # Don't override per-level token budgets (thinkingBudgets omitted).
      # Keep thinking blocks visible in the transcript.
      hideThinkingBlock = false;

    };
    # Left at upstream defaults otherwise: settings/keybindings/models render to
    # settings.json, keybindings.json and models.json under `configDir`
    # (~/.pi/agent), and `context` would write an AGENTS.md there. configDir is
    # deliberately not moved to $XDG_CONFIG_HOME — the module only exports
    # PI_CODING_AGENT_DIR when it differs from the upstream default, and the
    # agent's own state lives under ~/.pi regardless.
  };
}
