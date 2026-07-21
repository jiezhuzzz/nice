# flake-parts module that declares flake.nixosConfigurations,
# flake.darwinConfigurations, flake.homeConfigurations.
#
# The builders own all cross-cutting plumbing: `inputs` + `user` in every
# layer's specialArgs, home-manager wiring for the system builders, and the
# settings every machine sets (allowUnfree; flakes on NixOS). Profiles and
# hosts only describe what is specific to them.
{inputs, ...}: let
  user = import ../users/jie.nix;

  # HM module injected into every home-manager user, however it is wired in.
  hmSharedModules = [inputs.catppuccin.homeModules.catppuccin];

  # home-manager wiring shared by the NixOS and darwin system builders.
  hmSystemWiring = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {inherit inputs user;};
      sharedModules = hmSharedModules;

      # Move a conflicting file to <name>.bak instead of aborting activation.
      # Without this, any app that rewrites a home-manager-managed config in
      # place fails the whole switch with "would be clobbered" — noctalia's
      # theme templates did exactly that to ~/.config/ghostty/config by running
      # `sed -i` over the store symlink.
      #
      # Note this trades a loud failure for a silent one: the file is replaced
      # and the old copy left as .bak, so a config being fought over is no
      # longer obvious from the switch output. Activation also still fails if
      # the .bak name is itself taken, so stale backups need clearing.
      #
      # Only applies to the system builders; standalone home-manager (mkHome
      # below) has no such option and needs `home-manager switch -b bak`.
      backupFileExtension = "bak";
    };
  };

  mkNixos = modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs user;};
      modules =
        modules
        ++ [
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.agenix.nixosModules.default
          hmSystemWiring
          {
            nixpkgs.config.allowUnfree = true;
            nix.settings.experimental-features = ["nix-command" "flakes"];
            catppuccin.enable = true;
            catppuccin.autoEnable = true;
            catppuccin.flavor = user.theme.flavor;
          }
        ];
    };

  mkDarwin = modules:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = {inherit inputs user;};
      modules =
        modules
        ++ [
          inputs.home-manager.darwinModules.home-manager
          inputs.agenix.darwinModules.default
          hmSystemWiring
          {nixpkgs.config.allowUnfree = true;}
        ];
    };

  mkHome = system: modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {inherit inputs user;};
      modules = modules ++ hmSharedModules;
    };
in {
  flake.nixosConfigurations = {
    nixps = mkNixos [../hosts/nixos/nixps];
    nixmachine = mkNixos [../hosts/nixos/nixmachine];
  };

  flake.homeConfigurations = {
    chameleon = mkHome "x86_64-linux" [../hosts/foreign/chameleon];
    goku = mkHome "x86_64-linux" [../hosts/foreign/goku];
    vegeta = mkHome "x86_64-linux" [../hosts/foreign/vegeta];
  };

  flake.darwinConfigurations = {
    nixmini = mkDarwin [../hosts/macos/nixmini.nix];
    nixair = mkDarwin [../hosts/macos/nixair.nix];
    nixneo = mkDarwin [../hosts/macos/nixneo.nix];
  };
}
