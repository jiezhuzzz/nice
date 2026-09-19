{
  config,
  inputs,
  pkgs,
  ...
}: let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  piThemes = "${inputs.pi-catppuccin.packages.${pkgs.stdenv.hostPlatform.system}.default}/share/pi/themes";

  # Nord colors and segment order follow claude-code/statusline.nix.
  # `time` is the wall clock rather than elapsed session time, and `context`
  # reports the window consumed where ccstatusline inverts it to what is left.
  sep = "[ │ ](polar_night_3)";
  piStarshipSettings = {
    palette = "nord";
    palettes.nord = {
      polar_night_3 = "#4c566a";
      snow_storm_0 = "#d8dee9";
      frost_0 = "#8fbcbb";
      frost_1 = "#88c0d0";
      frost_2 = "#81a1c1";
      frost_3 = "#5e81ac";
      red = "#bf616a";
      yellow = "#ebcb8b";
      green = "#a3be8c";
      purple = "#b48ead";
    };
    # Branch and worktree sit in conditional groups so their separator leaves
    # with them outside a repo or a linked worktree.
    format = "$model $thinking${sep}$directory(${sep}$git_branch)(${sep}$git_worktree)${sep}$context${sep}$cost${sep}$time";
    model = {
      format = "[$model]($style)";
      style = "bold frost_1";
    };
    thinking = {
      format = "[$level]($style)";
      style = "frost_2";
    };
    directory = {
      format = "[$path]($style)";
      style = "snow_storm_0";
      fish_style_pwd_dir_length = 1;
    };
    git_branch = {
      format = "[$branch]($style)";
      style = "purple";
    };
    git_worktree = {
      format = "[$name]($style)";
      style = "frost_0";
    };
    context = {
      format = "[$percentage]($style)";
      display = [
        {
          threshold = 0;
          style = "green";
          hidden = false;
        }
      ];
    };
    cost = {
      symbol = "$";
      format = "[$symbol$cost]($style)";
      display = [
        {
          threshold = 0;
          style = "bold red";
          hidden = false;
        }
      ];
    };
  };
in {
  programs.pi-coding-agent = {
    enable = true;
    package = llmAgents.pi;
    configDir = "${config.xdg.configHome}/pi/agent";
    settings = {
      defaultProvider = "openai-codex";
      defaultModel = "gpt-6-astra";
      defaultThinkingLevel = "xhigh";
      quietStartup = true;
      hideThinkingBlock = false;
      packages = [
        # "npm:context-mode" # sandboxed code execution to shrink context use
        "npm:pi-mcp-adapter"
        "npm:pi-subagents"
        "npm:pi-web-access"
        "npm:@narumitw/pi-starship"
        "npm:pi-btw"

        "${inputs.ponytail}"
        "${inputs.caveman}"
      ];

      skills = ["${inputs.superpowers}/skills/systematic-debugging"];
      themes = [piThemes];
      theme = "catppuccin-${config.catppuccin.flavor}";
    };
  };

  # pi-starship reads exactly one file, <configDir>/pi-starship.toml, so this
  # has to track configDir above. `/starship settings` edits that same path and
  # will fail against a store symlink — treat the TUI as a preview.
  xdg.configFile."pi/agent/pi-starship.toml".source =
    (pkgs.formats.toml {}).generate "pi-starship.toml" piStarshipSettings;

  home.sessionVariables.PI_CODING_AGENT_SESSION_DIR = "${config.xdg.stateHome}/pi/sessions";
}
