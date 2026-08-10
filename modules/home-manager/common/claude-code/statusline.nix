# The ccstatusline status line: its generated settings.json and the
# settings.statusLine key that points Claude Code at it.
{
  inputs,
  pkgs,
  ...
}: let
  # ccstatusline from llm-agents.nix (like claude-code itself in settings.nix).
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # ccstatusline renders the status line from this JSON, replacing the
  # hand-rolled shell script that used to live here — which forked jq nine
  # times and git twice on every single render.
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
    # Longer than statusLine.refreshInterval (set below): the timed
    # re-renders exist for the session clock, and a TTL shorter than the
    # interval would re-fork git on every single tick for branch/worktree
    # names that change on human timescales.
    gitCacheTtlSeconds = 30;
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

  programs.claude-code.settings.statusLine = {
    type = "command";
    command = "${llmAgents.ccstatusline}/bin/ccstatusline";
    padding = 0;
    # Re-render between turns so the session clock stays live. Claude Code
    # honours this from 2.1.97 on.
    refreshInterval = 10;
  };
}
