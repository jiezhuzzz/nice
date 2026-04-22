{pkgs, ...}: {
  programs.aerospace = {
    enable = true;
    launchd = {
      enable = true;
    };
    settings = {
      enable-normalization-flatten-containers = true;
      enable-normalization-opposite-orientation-for-nested-containers = true;
      accordion-padding = 30;
      default-root-container-layout = "tiles";
      default-root-container-orientation = "auto";
      on-focused-monitor-changed = ["move-mouse monitor-lazy-center"];
      on-window-detected = [
        {
          "if".app-id = "com.mitchellh.ghostty";
          run = "move-node-to-workspace T";
        }
        {
          "if".app-id = "app.zen-browser.zen";
          run = "move-node-to-workspace B";
        }
        {
          "if".app-id = "dev.zed.Zed";
          run = "move-node-to-workspace E";
        }
        {
          "if".app-id = "com.tencent.xinWeChat";
          run = [
            "layout floating"
            "move-node-to-workspace C"
          ];
        }
        {
          "if".app-id = "com.apple.systempreferences";
          run = "layout floating";
        }
        {
          "if".app-id = "com.apple.finder";
          run = "layout floating";
        }
        {
          "if".app-id = "us.zoom.xos";
          run = "layout floating";
        }
        {
          "if".app-id = "app.portal.ios.v1";
          run = ["layout floating" "move-node-to-workspace M"];
        }
        {
          "if".app-id = "com.apple.AppStore";
          run = ["layout floating" "move-node-to-workspace M"];
        }
      ];
      gaps = {
        inner = {
          horizontal = 10;
          vertical = 10;
        };
        outer = {
          left = 10;
          bottom = 10;
          top = 10;
          right = 10;
        };
      };
      mode.main.binding = {
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";
        alt-f = "fullscreen";
        alt-shift-space = "layout floating tiling";
        alt-t = "workspace T"; # terminal
        alt-b = "workspace B"; # browser
        alt-e = "workspace E"; # editor
        alt-c = "workspace C"; # chat
        alt-m = "workspace M"; # misc
        alt-shift-t = "move-node-to-workspace T";
        alt-shift-b = "move-node-to-workspace B";
        alt-shift-e = "move-node-to-workspace E";
        alt-shift-c = "move-node-to-workspace C";
        alt-shift-m = "move-node-to-workspace M";
        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

        alt-shift-semicolon = "mode service";
      };
      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        alt-shift-h = [
          "join-with left"
          "mode main"
        ];
        alt-shift-j = [
          "join-with down"
          "mode main"
        ];
        alt-shift-k = [
          "join-with up"
          "mode main"
        ];
        alt-shift-l = [
          "join-with right"
          "mode main"
        ];
      };
    };
  };
}
