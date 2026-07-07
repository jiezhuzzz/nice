# profiles/homelab.nix
# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine): user
# `jie` gets the exact same home-manager toolkit as the standalone servers
# (profiles/home/server.nix), wired through the NixOS home-manager module so
# the two never drift. Boot, storage, networking and the user account stay
# with the host.
{user, ...}: {
  home-manager.users.${user.me.username}.imports = [./home/server.nix];

  # Headless box: no system-level theming. catppuccin/nix is transitioning
  # `enable` into a global toggle with `autoEnable` doing port enrollment;
  # setting enable=true + autoEnable=false keeps every port off under both
  # the old and new semantics, and silences the transition warning.
  catppuccin.enable = true;
  catppuccin.autoEnable = false;
}
