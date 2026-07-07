# profiles/homelab.nix
# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine).
# Gives user `jie` the exact same home-manager tooling as the standalone
# `server` profile — it reuses server.nix verbatim as the HM config, wired in
# through the NixOS home-manager module — so the two never drift. Boot,
# storage, networking and the user account stay with the host.
{inputs, ...}: let
  user = import ../users/jie.nix;
in {
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {
    # Same module set + settings as the standalone server profile.
    imports = [./home/server.nix];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
  };
}
