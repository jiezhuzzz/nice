# flake-parts module that declares flake.nixosConfigurations,
# flake.darwinConfigurations, flake.homeConfigurations.
{inputs, ...}: let
  # HM module injected into every home-manager user managed via NixOS/darwin
  hmSharedModules = [inputs.catppuccin.homeModules.catppuccin];

  mkNixos = modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules =
        modules
        ++ [
          inputs.home-manager.nixosModules.home-manager
          inputs.catppuccin.nixosModules.catppuccin
          inputs.agenix.nixosModules.default
          {home-manager.sharedModules = hmSharedModules;}
        ];
    };

  mkDarwin = modules:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = {inherit inputs;};
      modules =
        modules
        ++ [
          inputs.home-manager.darwinModules.home-manager
          {home-manager.sharedModules = hmSharedModules;}
        ];
    };

  mkHome = system: modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = {inherit inputs;};
      modules =
        modules
        ++ [
          inputs.catppuccin.homeModules.catppuccin
        ];
    };
in {
  flake.nixosConfigurations = {
    naptop = mkNixos [../hosts/nixos/naptop];
    nas = mkNixos [../hosts/nixos/nas];
  };

  flake.homeConfigurations = {
    "jie@server" = mkHome "x86_64-linux" [(../hosts/foreign + "/jie@server")];
  };

  flake.darwinConfigurations = {
    macmini = mkDarwin [../hosts/macos/macmini];
    nacbook = mkDarwin [../hosts/macos/nacbook];
  };
}
