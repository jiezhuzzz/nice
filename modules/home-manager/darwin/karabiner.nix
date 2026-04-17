{...}: {
  xdg.configFile."karabiner/karabiner.json" = {
    force = true;
    text = builtins.toJSON {
      global = {
        show_in_menu_bar = false;
      };
      profiles = [
        {
          name = "Default";
          selected = true;
          complex_modifications = {
            rules = [
              {
                description = "Caps Lock → Escape (alone) / Control (held)";
                manipulators = [
                  {
                    type = "basic";
                    from = {
                      key_code = "caps_lock";
                      modifiers.optional = ["any"];
                    };
                    to = [
                      {
                        key_code = "left_control";
                        lazy = true;
                      }
                    ];
                    to_if_alone = [
                      {
                        key_code = "escape";
                      }
                    ];
                  }
                ];
              }
            ];
          };
          virtual_hid_keyboard = {
            country_code = 0;
            keyboard_type_v2 = "ansi";
          };
        }
      ];
    };
  };
}
