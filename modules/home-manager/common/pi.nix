{
  config,
  inputs,
  pkgs,
  ...
}: let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  piThemes = "${inputs.pi-catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/pi/themes";
in {
  programs.pi-coding-agent = {
    enable = true;
    package = llmAgents.pi;
    configDir = "${config.xdg.configHome}/pi/agent";
    settings = {
      defaultProvider = "openai";
      defaultModel = "gpt-6-astra";
      defaultThinkingLevel = "xhigh";
      quietStartup = true;
      hideThinkingBlock = false;
      packages = [
        # "npm:context-mode" # sandboxed code execution to shrink context use
        "npm:pi-mcp-adapter"
        "npm:pi-subagents"
        "npm:pi-web-access"
        "npm:pi-powerline-footer"
        "npm:pi-btw"

        "${inputs.ponytail}"
        "${inputs.caveman}"
      ];

      skills = ["${inputs.superpowers}/skills/systematic-debugging"];
      themes = [piThemes];
      theme = "catppuccin-${config.catppuccin.flavor}";
    };
  };

  home.sessionVariables.PI_CODING_AGENT_SESSION_DIR = "${config.xdg.stateHome}/pi/sessions";
}
