{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.niri-flake.homeModules.config];

  programs.niri.settings = {
    input = {
      keyboard.xkb.layout = "us";
      touchpad = {
        tap = true;
        natural-scroll = true;
        # macOS-ish feel: adaptive accel, slightly slower base speed. Range -1.0 .. 1.0.
        accel-profile = "adaptive";
        accel-speed = -0.15;
        scroll-factor = 0.5;
      };
      mouse = {
        accel-profile = "adaptive";
        accel-speed = -0.15;
        scroll-factor = 0.5;
      };
    };

    outputs."eDP-1" = {
      # LG 14" 1920x1200 @ 120Hz, ~189 DPI
      mode = {
        width = 1920;
        height = 1200;
        refresh = 120.043;
      };
      scale = 1.25;
      # variable-refresh-rate = true;  # causes cursor micro-stutter on this panel
    };

    layout = {
      gaps = 8;
      center-focused-column = "never";
      preset-column-widths = [
        {proportion = 0.33333;}
        {proportion = 0.5;}
        {proportion = 0.66667;}
      ];
      default-column-width = {proportion = 0.5;};
      focus-ring.width = 2;
    };

    prefer-no-csd = true;
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    binds = let
      focusColLeft = {action.focus-column-left = {};};
      focusColRight = {action.focus-column-right = {};};
      focusWinUp = {action.focus-window-up = {};};
      focusWinDown = {action.focus-window-down = {};};
    in {
      # Apps
      "Alt+T" = {
        action.spawn = "ghostty";
        hotkey-overlay.title = "Terminal: ghostty";
      };
      "Alt+D" = {
        action.spawn = "fuzzel";
        hotkey-overlay.title = "App launcher: fuzzel";
      };
      "Alt+B" = {
        action.spawn = "zen";
        hotkey-overlay.title = "Browser: zen";
      };

      # Session
      "Alt+Q".action.close-window = {};
      "Alt+Shift+E".action.quit = {};
      "Alt+Shift+P".action.power-off-monitors = {};
      "Alt+Shift+L".action.spawn = ["loginctl" "lock-session"];

      # Focus (arrow + vim keys share actions)
      "Alt+Left" = focusColLeft;
      "Alt+H" = focusColLeft;
      "Alt+Right" = focusColRight;
      "Alt+L" = focusColRight;
      "Alt+Up" = focusWinUp;
      "Alt+K" = focusWinUp;
      "Alt+Down" = focusWinDown;
      "Alt+J" = focusWinDown;

      # Move
      "Alt+Shift+Left".action.move-column-left = {};
      "Alt+Shift+Right".action.move-column-right = {};
      "Alt+Shift+Up".action.move-window-up = {};
      "Alt+Shift+Down".action.move-window-down = {};

      # Workspaces
      "Alt+1".action.focus-workspace = 1;
      "Alt+2".action.focus-workspace = 2;
      "Alt+3".action.focus-workspace = 3;
      "Alt+4".action.focus-workspace = 4;
      "Alt+Shift+1".action.move-column-to-workspace = 1;
      "Alt+Shift+2".action.move-column-to-workspace = 2;
      "Alt+Shift+3".action.move-column-to-workspace = 3;
      "Alt+Shift+4".action.move-column-to-workspace = 4;

      # Column widths
      "Alt+R".action.switch-preset-column-width = {};
      "Alt+F".action.maximize-column = {};
      "Alt+Shift+F".action.fullscreen-window = {};

      # Screenshot
      "Print".action.screenshot = {};
      "Alt+Print".action.screenshot-window = {};

      # Volume / brightness (laptop keys)
      "XF86AudioRaiseVolume" = {
        action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"];
        allow-when-locked = true;
      };
      "XF86AudioLowerVolume" = {
        action.spawn = ["wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"];
        allow-when-locked = true;
      };
      "XF86AudioMute" = {
        action.spawn = ["wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
        allow-when-locked = true;
      };
      "XF86MonBrightnessUp".action.spawn = ["brightnessctl" "set" "10%+"];
      "XF86MonBrightnessDown".action.spawn = ["brightnessctl" "set" "10%-"];
    };
  };

  # niri tools & niri's ecosystem companions.
  home.packages = with pkgs; [
    fuzzel # app launcher (Alt+D)
    brightnessctl # brightness keys
    wl-clipboard # wayland clipboard
    grim # screenshot backend (used by niri's built-in screenshot)
    slurp # region selection
  ];
}
