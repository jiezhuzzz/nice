# profiles/homelab.nix
# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine): user
# `jie` gets the exact same home-manager toolkit as the standalone servers
# (profiles/home/server.nix), wired through the NixOS home-manager module so
# the two never drift. Boot, storage, networking and the user account stay
# with the host.
{user, ...}: {
  imports = [../modules/nixos/agenix-git.nix];
  home-manager.users.${user.me.username}.imports = [./home/server.nix];
}
