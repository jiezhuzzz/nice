# macOS system defaults (the `defaults write` equivalents).
_: {
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false; # don't auto-rearrange spaces by most-recent use
      tilesize = 48;

      persistent-apps = [
        "/Applications/WeChat.app"
        "/Applications/Ghostty.app"
        "/Applications/Zen.app"
        "/Applications/Zed.app"
      ];
    };

    finder = {
      AppleShowAllExtensions = true;
      FXEnableExtensionChangeWarning = false;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXDefaultSearchScope = "SCcf"; # search current folder by default
      FXPreferredViewStyle = "Nlsv"; # list view
      _FXShowPosixPathInTitle = true;
    };

    NSGlobalDomain = {
      AppleICUForce24HourTime = true;
      AppleShowAllExtensions = true;
      ApplePressAndHoldEnabled = false; # enable key repeat instead of accent popup
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      _HIHideMenuBar = true;
    };

    trackpad.Clicking = true;

    loginwindow.GuestEnabled = false;

    # Sonoma+: disable "click wallpaper to reveal desktop" — clicking empty
    # space on the desktop should do nothing, not hide all windows.
    WindowManager.EnableStandardClickToShowDesktop = false;
    # Disable Stage Manager entirely.
    WindowManager.GloballyEnabled = false;
    # Sequoia tiling: disable edge-drag, top-edge-drag, and option-drag tiling
    # so they don't fight with Aerospace's window management.
    WindowManager.EnableTilingByEdgeDrag = false;
    WindowManager.EnableTopTilingByEdgeDrag = false;
    WindowManager.EnableTilingOptionAccelerator = false;
  };
}
