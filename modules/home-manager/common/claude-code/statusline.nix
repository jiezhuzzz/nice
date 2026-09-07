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
  #
  # Plain text rather than powerline: Rio draws the window translucent with
  # per-cell opacity, so the powerline caps and arrows never sat on the same
  # background as the cells beside them. Foreground colours only, from the
  # Nord palette (https://www.nordtheme.com/docs/colors-and-palettes).
  nord = {
    polarNight3 = "hex:4c566a";
    snowStorm0 = "hex:d8dee9";
    frost0 = "hex:8fbcbb";
    frost1 = "hex:88c0d0";
    frost2 = "hex:81a1c1";
    frost3 = "hex:5e81ac";
    red = "hex:bf616a";
    orange = "hex:d08770";
    yellow = "hex:ebcb8b";
    green = "hex:a3be8c";
    purple = "hex:b48ead";
  };

  seg = id: type: color: extra: {inherit id type color;} // extra;

  # ccstatusline drops a separator whose preceding widget rendered nothing, so
  # the hidden branch and worktree segments leave no doubled bars behind.
  sep = id: {
    inherit id;
    type = "separator";
    character = "│";
    color = nord.polarNight3;
  };

  ccstatuslineSettings = {
    # Must equal ccstatusline's CURRENT_VERSION (2.2.29: 4). Anything lower is
    # migrated and written back — into the read-only store here, so the write
    # fails and every render falls back to defaults with "⚠ invalid config".
    version = 4;
    colorLevel = 3; # truecolor
    defaultPadding = " ";
    defaultPaddingSide = "both";
    # Longer than statusLine.refreshInterval below, or every timed re-render
    # (which exists for the clock) would re-fork git.
    gitCacheTtlSeconds = 30;
    lines = [
      [
        # Model and effort read as one pair, no bar between. `merge` has to be
        # the no-padding form: every widget is padded on both sides, so a plain
        # merge would leave a double space — hence the explicit single space put
        # back after it.
        (seg "model" "model" nord.frost1 {
          bold = true;
          rawValue = true;
          merge = "no-padding";
        })
        {
          id = "model-gap";
          type = "custom-text";
          customText = " ";
          merge = "no-padding";
        }
        (seg "effort" "thinking-effort" nord.frost2 {rawValue = true;})
        (sep "sep-cwd")
        (seg "cwd" "current-working-dir" nord.snowStorm0 {
          rawValue = true;
          metadata.fishStyle = "true";
        })
        (sep "sep-branch")
        (seg "branch" "git-branch" nord.purple {
          rawValue = true;
          metadata.hide = "no-git";
        })
        (sep "sep-worktree")
        # Renders nothing outside a linked worktree, so it costs no width there.
        (seg "worktree" "worktree-name" nord.frost0 {rawValue = true;})
        (sep "sep-ctx")
        (seg "ctx" "context-percentage" nord.green {metadata.inverse = "true";}) # percent remaining, not consumed
        (sep "sep-session")
        (seg "session" "session-usage" nord.yellow {})
        (sep "sep-weekly")
        (seg "weekly" "weekly-usage" nord.orange {})
        (sep "sep-cost")
        (seg "cost" "session-cost" nord.red {
          bold = true;
          rawValue = true;
        })
        (sep "sep-clock")
        (seg "clock" "session-clock" nord.frost3 {rawValue = true;})
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
  # safe on the render path as long as `version` above is current: ccstatusline
  # only writes back when migrating an older schema or when an `updatemessage`
  # key is present, and its git/timer caches go to ~/.cache/ccstatusline
  # regardless.
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
