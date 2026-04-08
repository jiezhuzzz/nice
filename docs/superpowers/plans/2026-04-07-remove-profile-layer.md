# Remove Profile Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the `profiles/` directory by inlining each profile's imports and config into its consuming host.

**Architecture:** Each of the 3 hosts currently imports one profile. We inline the profile contents into the host, then delete the `profiles/` directory. The change is purely structural — no behavior changes.

**Tech Stack:** Nix (nix-darwin, NixOS, flake-parts)

---

### Task 1: Inline workstation profile into naptop host

**Files:**
- Modify: `hosts/nixos/naptop/default.nix`

- [ ] **Step 1: Replace profile import with direct module imports and config**

In `hosts/nixos/naptop/default.nix`, replace the `imports` block and add the inlined config. The full file should become:

```nix
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ./hardware.nix
    ../../../modules/nixos/boot
    ../../../modules/nixos/hardware
    ../../../modules/nixos/desktop
    ../../../modules/nixos/secrets
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    wifitui
    git
    banana-cursor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  networking.hostName = "naptop";

  time.timeZone = "America/Chicago";

  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;

  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  networking.networkmanager.enable = true;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../../../modules/home-manager/common
      ../../../modules/home-manager/linux
    ];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
  };

  system.stateVersion = "26.05";
}
```

- [ ] **Step 2: Commit**

```bash
git add hosts/nixos/naptop/default.nix
git commit -m "naptop: inline workstation profile"
```

---

### Task 2: Inline darwin profile into macmini host

**Files:**
- Modify: `hosts/macos/macmini/default.nix`

- [ ] **Step 1: Replace profile import with direct module imports and config**

In `hosts/macos/macmini/default.nix`, replace the `imports` block and add the inlined config. The full file should become:

```nix
{
  inputs,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../modules/nix-darwin/homebrew
    ../../../modules/nix-darwin/system
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  programs.fish.enable = true;

  environment.systemPackages = with pkgs; [
    git
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  networking.hostName = "macmini";
  networking.computerName = "macmini";

  nixpkgs.hostPlatform = "aarch64-darwin";

  time.timeZone = "America/Chicago";

  system.primaryUser = user.me.username;

  users.users.${user.me.username} = {
    home = "/Users/${user.me.username}";
    shell = pkgs.fish;
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = {inherit inputs user;};
  home-manager.users.${user.me.username} = {...}: {
    imports = [
      ../../../modules/home-manager/common
    ];
    home.username = user.me.username;
    home.homeDirectory = "/Users/${user.me.username}";
  };

  system.stateVersion = 6;
}
```

- [ ] **Step 2: Commit**

```bash
git add hosts/macos/macmini/default.nix
git commit -m "macmini: inline darwin profile"
```

---

### Task 3: Inline server/nas profile into nas host

**Files:**
- Modify: `hosts/nixos/nas/default.nix`

- [ ] **Step 1: Replace profile import with inlined config**

In `hosts/nixos/nas/default.nix`, remove the profile import and add the two settings that `server.nix` provided. The full file should become:

```nix
{...}: let
  user = import ../../../users/jie.nix;
in {
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostName = "nas";

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = ["wheel"];
  };

  # TODO: add hardware.nix once nixos-generate-config has been run on the box
  # imports = imports ++ [ ./hardware.nix ];

  # Placeholder file systems so the config evaluates. REPLACE when real
  # hardware config exists.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "nodev";

  system.stateVersion = "26.05";
}
```

- [ ] **Step 2: Commit**

```bash
git add hosts/nixos/nas/default.nix
git commit -m "nas: inline server/nas profile"
```

---

### Task 4: Delete profiles directory

**Files:**
- Delete: `profiles/darwin.nix`
- Delete: `profiles/workstation.nix`
- Delete: `profiles/server.nix`
- Delete: `profiles/nas.nix`

- [ ] **Step 1: Remove the profiles directory**

```bash
git rm -r profiles/
```

- [ ] **Step 2: Commit**

```bash
git commit -m "remove profiles/ directory"
```

---

### Task 5: Verify

- [ ] **Step 1: Run flake check**

```bash
nix flake check
```

Expected: no errors. All three configurations (naptop, macmini, nas) evaluate successfully.

- [ ] **Step 2: Format**

```bash
nix fmt
```

- [ ] **Step 3: Commit if formatting changed anything**

```bash
git add -A && git commit -m "style: format after profile removal"
```
