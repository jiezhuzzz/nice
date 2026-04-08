# macOS system defaults (the `defaults write` equivalents).
{...}: {
  system.defaults = {
    dock = {
      autohide = true;
      show-recents = false;
      mru-spaces = false; # don't auto-rearrange spaces by most-recent use
      tilesize = 48;
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
    };

    trackpad = {
      Clicking = true; # tap to click
      TrackpadThreeFingerDrag = true;
    };

    loginwindow.GuestEnabled = false;
  };
}
