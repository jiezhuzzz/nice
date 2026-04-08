{inputs, ...}: {
  imports = [inputs.xremap-flake.nixosModules.default];

  services.xremap = {
    enable = true;
    withWlroots = true;
    deviceNames = ["kanata"];
    config.keymap = [
      {
        name = "Super-to-Ctrl for Zen";
        application.only = ["zen"];
        remap = {
          "Super_L-a" = "C-a";
          "Super_L-c" = "C-c";
          "Super_L-f" = "C-f";
          "Super_L-l" = "C-l";
          "Super_L-n" = "C-n";
          "Super_L-r" = "C-r";
          "Super_L-t" = "C-t";
          "Super_L-v" = "C-v";
          "Super_L-w" = "C-w";
          "Super_L-x" = "C-x";
          "Super_L-z" = "C-z";
          "Super_L-Shift-t" = "C-Shift-t";
          "Super_L-Shift-z" = "C-Shift-z";
        };
      }
    ];
  };
}
