# Profiles Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `profiles/` directory with cross-layer module bundles so host files only contain identity and overrides.

**Architecture:** Each profile is a standard Nix module (darwin, nixos, or HM) that imports from `modules/` and sets shared config. Host files import one profile + host-specific overrides. No changes to `lib/mk-hosts.nix` or the module layer.

**Tech Stack:** Nix, nix-darwin, NixOS, home-manager

---

### Task 1: Create `profiles/darwin-desktop.nix`

**Files:**
- Create: `profiles/darwin-desktop.nix`

- [ ] **Step 1: Create the profile file**

```nix
# profiles/darwin-desktop.nix
# Shared darwin profile for all macOS desktop machines.
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../users/jie.nix;
in {
  imports = [
    ../modules/nix-darwin/fonts
    ../modules/nix-darwin/homebrew
    ../modules/nix-darwin/secrets
    ../modules/nix-darwin/system
  ];

  nixpkgs.config.allowUnfree = true;
  nix.enable = false;

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  system.primaryUser = user.me.username;

  users.knownUsers = [user.me.username];
  users.users.${user.me.username} = {
    uid = 501;
    home = "/Users/${user.me.username}";
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../modules/home-manager/common
      ../modules/home-manager/darwin/aerospace.nix
      ../modules/home-manager/darwin/karabiner.nix
      ../modules/home-manager/darwin/packages.nix
    ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
  };

  system.stateVersion = 6;
}
```

- [ ] **Step 2: Commit**

```bash
git add profiles/darwin-desktop.nix
git commit -m "feat: add darwin-desktop profile"
```

---

### Task 2: Simplify macOS host files to use the profile

**Files:**
- Modify: `hosts/macos/nixmini.nix`
- Modify: `hosts/macos/nixair.nix`
- Modify: `hosts/macos/nixneo.nix`

- [ ] **Step 1: Rewrite `hosts/macos/nixmini.nix`**

```nix
{...}: {
  imports = [../../profiles/darwin-desktop.nix];
  networking.hostName = "nixmini";
  networking.computerName = "nixmini";
  home-manager.backupFileExtension = "backup";
}
```

- [ ] **Step 2: Rewrite `hosts/macos/nixair.nix`**

```nix
{...}: {
  imports = [../../profiles/darwin-desktop.nix];
  networking.hostName = "nixair";
  networking.computerName = "nixair";
}
```

- [ ] **Step 3: Rewrite `hosts/macos/nixneo.nix`**

```nix
{...}: {
  imports = [../../profiles/darwin-desktop.nix];
  networking.hostName = "nixneo";
  networking.computerName = "nixneo";
}
```

- [ ] **Step 4: Verify evaluation**

Run on this macOS machine:

```bash
nix eval .#darwinConfigurations.nixmini.config.networking.hostName
nix eval .#darwinConfigurations.nixair.config.networking.hostName
nix eval .#darwinConfigurations.nixneo.config.networking.hostName
```

Expected: each prints its respective hostname string.

- [ ] **Step 5: Commit**

```bash
git add hosts/macos/nixmini.nix hosts/macos/nixair.nix hosts/macos/nixneo.nix
git commit -m "refactor: macOS hosts use darwin-desktop profile"
```

---

### Task 3: Create `profiles/nixos-desktop.nix`

**Files:**
- Create: `profiles/nixos-desktop.nix`

- [ ] **Step 1: Create the profile file**

```nix
# profiles/nixos-desktop.nix
# Shared NixOS profile for desktop/laptop machines.
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../users/jie.nix;
in {
  imports = [
    ../modules/nixos/boot
    ../modules/nixos/hardware
    ../modules/nixos/desktop
    ../modules/nixos/secrets
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;

  networking.networkmanager.enable = true;

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../modules/home-manager/common
      ../modules/home-manager/linux
    ];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
  };
}
```

- [ ] **Step 2: Commit**

```bash
git add profiles/nixos-desktop.nix
git commit -m "feat: add nixos-desktop profile"
```

---

### Task 4: Simplify nixps host to use the profile

**Files:**
- Modify: `hosts/nixos/nixps/default.nix`

- [ ] **Step 1: Rewrite `hosts/nixos/nixps/default.nix`**

```nix
{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ../../../profiles/nixos-desktop.nix
    ./hardware.nix
  ];

  networking.hostName = "nixps";

  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    wifitui
    banana-cursor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  system.stateVersion = "26.05";
}
```

- [ ] **Step 2: Verify evaluation**

```bash
nix eval .#nixosConfigurations.nixps.config.networking.hostName
```

Expected: `"nixps"`

- [ ] **Step 3: Commit**

```bash
git add hosts/nixos/nixps/default.nix
git commit -m "refactor: nixps uses nixos-desktop profile"
```

---

### Task 5: Create `profiles/server.nix`

**Files:**
- Create: `profiles/server.nix`

- [ ] **Step 1: Create the profile file**

```nix
# profiles/server.nix
# Shared home-manager profile for standalone HM on non-NixOS servers.
{...}: {
  imports = [
    ../modules/home-manager/common
    ../modules/home-manager/linux
  ];
}
```

- [ ] **Step 2: Commit**

```bash
git add profiles/server.nix
git commit -m "feat: add server profile"
```

---

### Task 6: Simplify chameleon host to use the profile

**Files:**
- Modify: `hosts/foreign/chameleon/default.nix`

- [ ] **Step 1: Rewrite `hosts/foreign/chameleon/default.nix`**

```nix
# Standalone home-manager config for the Chameleon Cloud server.
# Activate with: home-manager switch --flake .#chameleon
{...}: {
  imports = [../../../profiles/server.nix];

  home.username = "cc";
  home.homeDirectory = "/home/cc";

  catppuccin.bottom.enable = false;
}
```

- [ ] **Step 2: Verify evaluation**

```bash
nix eval .#homeConfigurations.chameleon.config.home.username
```

Expected: `"cc"`

- [ ] **Step 3: Commit**

```bash
git add hosts/foreign/chameleon/default.nix
git commit -m "refactor: chameleon uses server profile"
```
