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
                description = "Caps Lock → Escape (alone) / Control (held) [any keyboard except HHKB]";
                manipulators = [
                  {
                    type = "basic";
                    # Applies to the built-in keyboard, the Lofree Flow2 (which
                    # exposes no usable vendor/product id over Bluetooth LE), and
                    # any other standard-layout keyboard. The HHKB is excluded
                    # because it has its own left_control rule below.
                    conditions = [
                      {
                        type = "device_unless";
                        identifiers = [
                          {
                            vendor_id = 1278;
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
          devices = [
            {
              identifiers = {
                is_keyboard = true;
                is_pointing_device = true;
                vendor_id = 1278;
                product_id = 22;
              };
              ignore = false;
            }
            {
              # Lofree Flow2 over Bluetooth LE — identified by its BLE address
              # (no usable vendor/product id). Treated as built-in so the
              # caps_lock rule above (device_unless vendor_id 1278) applies.
              identifiers = {
                device_address = "c8-01-29-28-fe-5e";
                is_keyboard = true;
                is_pointing_device = true;
              };
              ignore = false;
              treat_as_built_in_keyboard = true;
            }
          ];
          virtual_hid_keyboard = {
            country_code = 0;
            keyboard_type_v2 = "ansi";
          };
        }
      ];
    };
  };
}
