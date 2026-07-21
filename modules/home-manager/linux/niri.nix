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
            // Tap-and-drag: tap, then hold on the second tap to drag. This
            // is libinput's default; stated explicitly so it is not lost.
            drag true
            // clickfinger over libinput's button-areas default: press anywhere
            // with one finger for left click, two fingers for right click,
            // as on macOS. button-areas instead reserves the bottom-right
            // corner for right click, which is easy to miss.
            //
            // The physical click depends on touchpad-rebind.service in
            // modules/nixos/hardware/touchpad.nix — without that rebind the
            // pad intermittently reports no button press at all, and this
            // setting has nothing to act on.
            click-method "clickfinger"
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
        // scale 1.0: render at the panel's native 1920x1200 rather than the
        // 1536x960 logical size 1.25 produced. Apps size in logical points,
        // so 1.25 inflated everything by 25% — most visibly ghostty, whose
        // font-size 16 comes from the shared module and is tuned for macOS.
        scale 1.0
        transform "normal"
        mode "1920x1200@120.043000"
    }
    screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
    prefer-no-csd
    // Rounded window corners, to match noctalia's shell surfaces.
    // clip-to-geometry is required as well: without it the window contents
    // still paint square corners underneath the rounded geometry.
    // 20 is the radius upstream recommends for v5.
    window-rule {
        geometry-corner-radius 20
        clip-to-geometry true
    }
    // noctalia's own settings window: float it at a usable size instead of
    // letting it tile into the column layout.
    window-rule {
        match app-id="dev.noctalia.Noctalia"
        open-floating true
        default-column-width { fixed 1080; }
        default-window-height { fixed 920; }
    }
    // noctalia provides the bar, notifications and control centre. It is
    // started by its systemd user service (programs.noctalia.systemd.enable in
    // noctalia.nix), NOT spawn-at-startup — doing both would run two copies.
    // https://docs.noctalia.dev/v5/compositor-settings/niri/
    // Required by noctalia: lets it act on notification buttons and raise
    // windows, which otherwise fail the xdg-activation serial check.
    debug {
        honor-xdg-activation-with-invalid-serial
    }
    // Draws the overview wallpaper behind noctalia's overview layer.
    layer-rule {
        match namespace="^noctalia-overview*"
        place-within-backdrop true
    }
    layout {
        gaps 8
        struts {
            left 0
            right 0
            top 0
            bottom 0
        }
        // Neutral rather than an accent colour: niri's default sky blue and
        // catppuccin mauve both read as a coloured frame around every window.
        // surface2/surface0 keep a focus cue that does not draw the eye.
        // `focus-ring { off; }` removes it entirely — but border is off too,
        // so that leaves no focus indication at all with several columns open.
        focus-ring {
            width 2
            active-color "#626880"
            inactive-color "#414559"
        }
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
        // Must match home.pointerCursor.size in profiles/nixos-desktop.nix:
        // niri stamps XCURSOR_SIZE onto every client it spawns, so this value
        // wins over the one home-manager exports.
        xcursor-size 40
    }
    binds {
        // Workspaces
        Alt+1 { focus-workspace 1; }
        Alt+2 { focus-workspace 2; }
        Alt+3 { focus-workspace 3; }
        Alt+4 { focus-workspace 4; }
        // Apps
        Alt+B hotkey-overlay-title="Browser: chromium" { spawn "chromium"; }
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
        // noctalia panels
        Alt+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
        Alt+S { spawn-sh "noctalia msg panel-toggle control-center"; }
        Alt+Comma { spawn-sh "noctalia msg settings-toggle"; }
        Alt+Tab { spawn-sh "noctalia msg window-switcher"; }
        // Volume / brightness (laptop keys)
        //
        // Routed through noctalia rather than wpctl/brightnessctl directly so
        // its OSD actually appears — [osd.kinds] volume/brightness only fire
        // for changes noctalia itself makes. The trade-off is that these keys
        // do nothing if noctalia is not running.
        XF86AudioLowerVolume allow-when-locked=true { spawn-sh "noctalia msg volume-down"; }
        XF86AudioMute allow-when-locked=true { spawn-sh "noctalia msg volume-mute"; }
        XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "noctalia msg volume-up"; }
        XF86MonBrightnessDown { spawn-sh "noctalia msg brightness-down"; }
        XF86MonBrightnessUp { spawn-sh "noctalia msg brightness-up"; }
    }
  '';

  # niri tools & niri's ecosystem companions.
  home.packages = with pkgs; [
    brightnessctl # CLI backlight control; the keys go through noctalia now
    wl-clipboard # wl-copy/wl-paste; no CLI equivalent in noctalia's clipboard panel
  ];
}
