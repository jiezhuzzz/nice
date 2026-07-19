{pkgs, ...}: {
  # niri is enabled system-side by modules/nixos/desktop/niri.nix, which uses
  # the nixpkgs module (programs.niri.enable). That module offers enable,
  # package and useNautilus only — it has no config generator, and
  # home-manager has no niri module upstream, so the compositor config is
  # written here as literal KDL.
  #
  # This file previously used niri-flake's `programs.niri.settings`, which
  # generated the KDL from typed Nix. Dropping that input removed four
  # transitive lock entries and a version skew: niri-flake's home-manager
  # module defaulted to niri 25.08 while the system actually runs the nixpkgs
  # niri (26.04 at the time of the change). The cost is that this KDL is
  # hand-maintained and unvalidated at eval time — `niri validate` is the
  # check, and it runs in the flake's checks.
  xdg.configFile."niri/config.kdl".text = ''
    input {
        keyboard {
            xkb {
                layout "us"
                model ""
                rules ""
                variant ""
            }
            repeat-delay 600
            repeat-rate 25
            track-layout "global"
        }
        // macOS-ish feel: adaptive accel, slightly slower base speed.
        // accel-speed range is -1.0 .. 1.0.
        touchpad {
            tap
            natural-scroll
            accel-speed -0.150000
            accel-profile "adaptive"
            scroll-factor 0.500000
        }
        mouse {
            accel-speed -0.150000
            accel-profile "adaptive"
            scroll-factor 0.500000
        }
    }
    // LG 14" 1920x1200 @ 120Hz, ~189 DPI.
    // variable-refresh-rate causes cursor micro-stutter on this panel.
    output "eDP-1" {
        scale 1.250000
        transform "normal"
        mode "1920x1200@120.043000"
    }
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
    prefer-no-csd
    layout {
        gaps 8
        struts {
            left 0
            right 0
            top 0
            bottom 0
        }
        focus-ring { width 2; }
        border { off; }
        default-column-width { proportion 0.500000; }
        preset-column-widths {
            proportion 0.333330
            proportion 0.500000
            proportion 0.666670
        }
        center-focused-column "never"
    }
    // Theme/size are kept in step with home.pointerCursor in
    // profiles/nixos-desktop.nix; niri reads its own cursor setting.
    cursor {
        xcursor-theme "Banana"
        xcursor-size 32
    }
    binds {
        // Workspaces
        Alt+1 { focus-workspace 1; }
        Alt+2 { focus-workspace 2; }
        Alt+3 { focus-workspace 3; }
        Alt+4 { focus-workspace 4; }
        // Apps
        Alt+B hotkey-overlay-title="Browser: chromium" { spawn "chromium"; }
        Alt+D hotkey-overlay-title="App launcher: fuzzel" { spawn "fuzzel"; }
        Alt+T hotkey-overlay-title="Terminal: ghostty" { spawn "ghostty"; }
        // Focus (arrow + vim keys share actions)
        Alt+Down { focus-window-down; }
        Alt+H { focus-column-left; }
        Alt+J { focus-window-down; }
        Alt+K { focus-window-up; }
        Alt+L { focus-column-right; }
        Alt+Left { focus-column-left; }
        Alt+Right { focus-column-right; }
        Alt+Up { focus-window-up; }
        // Column widths
        Alt+F { maximize-column; }
        Alt+R { switch-preset-column-width; }
        Alt+Shift+F { fullscreen-window; }
        // Session
        Alt+Q { close-window; }
        Alt+Shift+E { quit; }
        Alt+Shift+L { spawn "swaylock"; }
        Alt+Shift+P { power-off-monitors; }
        // Move
        Alt+Shift+1 { move-column-to-workspace 1; }
        Alt+Shift+2 { move-column-to-workspace 2; }
        Alt+Shift+3 { move-column-to-workspace 3; }
        Alt+Shift+4 { move-column-to-workspace 4; }
        Alt+Shift+Down { move-window-down; }
        Alt+Shift+Left { move-column-left; }
        Alt+Shift+Right { move-column-right; }
        Alt+Shift+Up { move-window-up; }
        // Screenshot
        Alt+Print { screenshot-window; }
        Print { screenshot; }
        // Volume / brightness (laptop keys)
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }
        XF86MonBrightnessUp { spawn "brightnessctl" "set" "10%+"; }
    }
  '';

  # niri tools & niri's ecosystem companions.
  home.packages = with pkgs; [
    fuzzel # app launcher (Alt+D)
    brightnessctl # brightness keys
    wl-clipboard # wayland clipboard
    grim # screenshot backend (used by niri's built-in screenshot)
    slurp # region selection
  ];
}
