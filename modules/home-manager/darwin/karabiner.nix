_: {
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
                description = "Caps Lock → Escape (alone) / Control (held) [Apple keyboard]";
                manipulators = [
                  {
                    type = "basic";
                    conditions = [
                      {
                        type = "device_if";
                        identifiers = [
                          {
                            is_built_in_keyboard = true;
                          }
                        ];
                      }
                    ];
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
              {
                description = "Control → Escape (alone) / Control (held) [HHKB]";
                manipulators = [
                  {
                    type = "basic";
                    conditions = [
                      {
                        type = "device_if";
                        identifiers = [
                          {
                            vendor_id = 1278;
                          }
                        ];
                      }
                    ];
                    from = {
                      key_code = "left_control";
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
