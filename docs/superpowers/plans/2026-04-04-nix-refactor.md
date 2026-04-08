# Nix Config Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the flat single-host Nix flake into a multi-host/multi-OS
structure (laptop, macOS, Ubuntu server w/ home-manager, NAS) without changing
any runtime behavior on the current laptop.

**Architecture:** `flake-parts` with small helpers in `lib/mk-hosts.nix`. OS
module folders (`modules/{nixos,darwin,home}`) + role profiles
(`profiles/{workstation,server,nas}.nix`). Per-host folders under
`hosts/{nixos,darwin,foreign}/`. Identity centralized in `users/jie.nix`.

**Tech Stack:** Nix flakes, flake-parts, nixpkgs-unstable, home-manager,
nix-darwin, nixos-hardware.

**Verification strategy:** Because this refactor must not change behavior on
`naptop`, every verification step compares the rebuilt system closure against
a baseline captured at Task 1. We use `nvd diff` (or a plain store-path
comparison) — acceptable outcomes are *no differences* or only trivially
inconsequential ones (e.g., derivation ordering).

---

### Task 1: Capture baseline & set up working branch

**Files:**
- Create: `.baseline-toplevel` (gitignored, local reference only)

- [ ] **Step 1: Confirm working tree clean & on main**

Run: `git status --short && git branch --show-current`
Expected: no output from `git status --short`; branch is `main`.

- [ ] **Step 2: Build current system closure from the old flake**

Run:
```bash
cd /home/jie/repo/nice
nix build --no-link --print-out-paths .#nixosConfigurations.naptop.config.system.build.toplevel | tee .baseline-toplevel
```
Expected: prints one `/nix/store/...-nixos-system-naptop-26.05...` path. Save it.

- [ ] **Step 3: Gitignore the baseline file**

Create/append `.gitignore`:
```
.baseline-toplevel
```

- [ ] **Step 4: Install nvd (diff tool) if not present**

Run: `nix shell nixpkgs#nvd -c nvd --version`
Expected: version string prints.

- [ ] **Step 5: Commit the .gitignore**

```bash
git add .gitignore
git commit -m "chore: gitignore baseline-toplevel reference"
```

---

### Task 2: Create directory skeleton & users/jie.nix

**Files:**
- Create: `users/jie.nix`
- Create empty dirs via `.gitkeep`: `hosts/nixos/`, `hosts/darwin/`,
  `hosts/foreign/`, `profiles/`, `modules/nixos/`, `modules/darwin/`,
  `modules/home/{common,linux,darwin}/`, `lib/`

- [ ] **Step 1: Create directory tree with placeholders**

Run:
```bash
cd /home/jie/repo/nice
mkdir -p hosts/nixos hosts/darwin hosts/foreign profiles lib \
         modules/nixos modules/darwin \
         modules/home/common modules/home/linux modules/home/darwin
touch hosts/nixos/.gitkeep hosts/darwin/.gitkeep hosts/foreign/.gitkeep \
      profiles/.gitkeep modules/darwin/.gitkeep \
      modules/home/darwin/.gitkeep
```

- [ ] **Step 2: Write `users/jie.nix`**

File content:
```nix
# Shared identity + theme. Imported by NixOS system configs AND by
# home-manager modules so both sides stay in sync.
{
  me = {
    username = "jie";
    fullname = "jiezhuzzz";
    email = "jiezzz@duck.com";
  };
  theme = {
    flavor = "frappe";  # catppuccin flavor
  };
}
```

- [ ] **Step 3: Commit**

```bash
mkdir -p users
mv users/jie.nix users/jie.nix  # (already there)
git add users/jie.nix hosts modules profiles lib
git commit -m "chore: scaffold new directory layout + users/jie.nix"
```

---

### Task 3: Extract `modules/nixos/boot/`

**Files:**
- Create: `modules/nixos/boot/default.nix`

- [ ] **Step 1: Write the module**

File `modules/nixos/boot/default.nix`:
```nix
{ pkgs, ... }:
{
  # systemd-boot EFI
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 0; # Hold Space during boot for menu
  boot.loader.efi.canTouchEfiVariables = true;

  # Graphical boot splash with LUKS password prompt (Esc for text)
  boot.plymouth.enable = true;

  # Latest kernel
  # TODO: Switch to 7.0+ when available for Dell XPS 14 (Panther Lake)
  # CS42L45 audio — https://github.com/thesofproject/linux/issues/5720
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Prevent kernel crash in sdca_jack_process on PTL — CS42L45 missing in 6.19
  # Remove when upgrading to kernel 7.0+
  boot.extraModprobeConfig = ''
    options snd_sof disable_function_topology=1
  '';
}
```

- [ ] **Step 2: Commit**

```bash
git add modules/nixos/boot/default.nix
git commit -m "refactor: extract nixos boot module"
```

---

### Task 4: Extract `modules/nixos/hardware/` submodules

**Files:**
- Create: `modules/nixos/hardware/default.nix`
- Create: `modules/nixos/hardware/power.nix`
- Create: `modules/nixos/hardware/audio.nix`
- Create: `modules/nixos/hardware/kanata.nix`
- Create: `modules/nixos/hardware/firmware.nix`

- [ ] **Step 1: Write `power.nix`**

```nix
{ ... }:
{
  # Lid close behavior
  # TODO: revert to suspend when s2idle works on Panther Lake (kernel 7.0+)
  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "ignore";
  };

  powerManagement.enable = true;
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = false;
  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = { governor = "powersave"; turbo = "never"; };
    charger = { governor = "performance"; turbo = "auto"; };
  };
}
```

- [ ] **Step 2: Write `audio.nix`**

```nix
{ ... }:
{
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
}
```

- [ ] **Step 3: Write `firmware.nix`**

```nix
{ ... }:
{
  hardware.enableAllFirmware = true;
  services.fwupd.enable = true;
}
```

- [ ] **Step 4: Write `kanata.nix`**

```nix
{ ... }:
{
  # CapsLock → Esc (tap) / Ctrl (hold)
  services.kanata = {
    enable = true;
    keyboards.default = {
      devices = [ ];
      config = ''
        (defsrc
          caps
        )
        (defalias
          escctrl (tap-hold 200 200 esc lctl)
        )
        (deflayer default
          @escctrl
        )
      '';
    };
  };
}
```

- [ ] **Step 5: Write `default.nix` aggregator**

```nix
{
  imports = [
    ./power.nix
    ./audio.nix
    ./firmware.nix
    ./kanata.nix
  ];
}
```

- [ ] **Step 6: Commit**

```bash
git add modules/nixos/hardware/
git commit -m "refactor: extract nixos hardware modules (power, audio, firmware, kanata)"
```

---

### Task 5: Extract `modules/nixos/desktop/`

**Files:**
- Create: `modules/nixos/desktop/default.nix`
- Create: `modules/nixos/desktop/gnome.nix`
- Create: `modules/nixos/desktop/input-method.nix`
- Create: `modules/nixos/desktop/fonts.nix`

- [ ] **Step 1: Write `gnome.nix`**

```nix
{ ... }:
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Fractional scaling in GNOME Wayland + cursor + lid actions
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']

    [org.gnome.settings-daemon.plugins.power]
    lid-close-ac-action='nothing'
    lid-close-battery-action='nothing'

    [org.gnome.desktop.interface]
    cursor-theme='Banana'
  '';
}
```

- [ ] **Step 2: Write `input-method.nix`**

```nix
{ pkgs, ... }:
{
  # Chinese input method (Rime via fcitx5)
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-rime ];
  };
}
```

- [ ] **Step 3: Write `fonts.nix`**

```nix
{ pkgs, ... }:
{
  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    maple-mono.NF
  ];
}
```

- [ ] **Step 4: Write `default.nix` aggregator**

```nix
{
  imports = [
    ./gnome.nix
    ./input-method.nix
    ./fonts.nix
  ];
}
```

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/desktop/
git commit -m "refactor: extract nixos desktop modules (gnome, input-method, fonts)"
```

---

### Task 6: Create `profiles/workstation.nix` (+ stub server, nas)

**Files:**
- Create: `profiles/workstation.nix`
- Create: `profiles/server.nix`
- Create: `profiles/nas.nix`

- [ ] **Step 1: Write `profiles/workstation.nix`**

```nix
# Workstation profile: desktop apps, dev tools, GUI, niri window manager.
# Intended for NixOS hosts that are interactive workstations.
{ pkgs, inputs, ... }:
{
  imports = [
    ../modules/nixos/boot
    ../modules/nixos/hardware
    ../modules/nixos/desktop
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    helix
    wifitui
    git
    banana-cursor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
```

- [ ] **Step 2: Write `profiles/server.nix` (minimal stub)**

```nix
# Headless server profile. Populated when the NAS/server hosts are fleshed out.
{ ... }:
{
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

- [ ] **Step 3: Write `profiles/nas.nix` (minimal stub)**

```nix
# NAS profile. Populated when the NAS host is fleshed out
# (ZFS, samba, media services, etc.).
{ ... }:
{
  imports = [ ./server.nix ];
}
```

- [ ] **Step 4: Commit**

```bash
git add profiles/
git commit -m "refactor: add workstation profile + server/nas stubs"
```

---

### Task 7: Extract `modules/home/`

**Files:**
- Create: `modules/home/common/default.nix`
- Create: `modules/home/common/packages.nix`
- Create: `modules/home/common/theme.nix`
- Create: `modules/home/linux/default.nix`
- Create: `modules/home/linux/packages.nix`

- [ ] **Step 1: Write `modules/home/common/packages.nix`**

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ghostty
    claude-code
    zed-editor
  ];
}
```

- [ ] **Step 2: Write `modules/home/common/theme.nix`**

```nix
{ ... }:
let user = import ../../../users/jie.nix;
in {
  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;
}
```

- [ ] **Step 3: Write `modules/home/common/default.nix`**

```nix
{ ... }:
{
  imports = [
    ./packages.nix
    ./theme.nix
  ];

  programs.home-manager.enable = true;
  home.stateVersion = "26.05";
}
```

- [ ] **Step 4: Write `modules/home/linux/packages.nix`**

```nix
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wechat-uos
  ];
}
```

- [ ] **Step 5: Write `modules/home/linux/default.nix`**

```nix
{
  imports = [ ./packages.nix ];
}
```

- [ ] **Step 6: Commit**

```bash
git add modules/home/
git commit -m "refactor: extract home-manager modules (common + linux)"
```

---

### Task 8: Write `lib/mk-hosts.nix`

**Files:**
- Create: `lib/mk-hosts.nix`

- [ ] **Step 1: Write the flake-parts module**

```nix
# flake-parts module that declares flake.nixosConfigurations,
# flake.darwinConfigurations, flake.homeConfigurations.
{ inputs, ... }:
let
  mkNixos = modules:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = modules ++ [
        inputs.home-manager.nixosModules.home-manager
        inputs.catppuccin.nixosModules.catppuccin
      ];
    };

  mkDarwin = modules:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };
      modules = modules ++ [
        inputs.home-manager.darwinModules.home-manager
      ];
    };

  mkHome = system: modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      extraSpecialArgs = { inherit inputs; };
      modules = modules ++ [
        inputs.catppuccin.homeModules.catppuccin
      ];
    };
in {
  flake.nixosConfigurations = {
    naptop = mkNixos [ ../hosts/nixos/naptop ];
  };

  # Darwin & foreign configs get added as those hosts come online.
  # flake.darwinConfigurations.<macname> = mkDarwin [ ../hosts/darwin/<macname> ];
  # flake.homeConfigurations."jie@server" =
  #   mkHome "x86_64-linux" [ ../hosts/foreign/jie@server ];
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/mk-hosts.nix
git commit -m "refactor: add flake-parts host-wiring module"
```

---

### Task 9: Create `hosts/nixos/naptop/`

**Files:**
- Create: `hosts/nixos/naptop/default.nix`
- Create: `hosts/nixos/naptop/hardware.nix` (copied verbatim from
  `hardware-configuration.nix`)

- [ ] **Step 1: Copy hardware config verbatim**

Run:
```bash
cp /home/jie/repo/nice/hardware-configuration.nix \
   /home/jie/repo/nice/hosts/nixos/naptop/hardware.nix
```

- [ ] **Step 2: Write the host entry `hosts/nixos/naptop/default.nix`**

```nix
{ pkgs, ... }:
let user = import ../../../users/jie.nix;
in {
  imports = [
    ./hardware.nix
    ../../../profiles/workstation.nix
  ];

  networking.hostName = "naptop";

  # Catppuccin system-wide
  catppuccin.enable = true;
  catppuccin.flavor = user.theme.flavor;

  # 8 GB swapfile
  swapDevices = [{
    device = "/swapfile";
    size = 8192;
  }];

  # User account
  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # Networking
  networking.networkmanager.enable = true;

  # Home-manager for this user
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit user; };
  home-manager.users.${user.me.username} = { ... }: {
    imports = [
      ../../../modules/home/common
      ../../../modules/home/linux
    ];
    home.username = user.me.username;
    home.homeDirectory = "/home/${user.me.username}";
  };

  system.stateVersion = "26.05";
}
```

- [ ] **Step 3: Commit**

```bash
git add hosts/nixos/naptop/
git commit -m "refactor: add naptop host entry"
```

---

### Task 10: Rewrite `flake.nix`

**Files:**
- Modify: `flake.nix` (complete rewrite)

- [ ] **Step 1: Overwrite `flake.nix`**

```nix
{
  description = "jie's nix configuration (laptop, mac, server, nas)";

  inputs = {
    nixpkgs.url      = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts.url  = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url   = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    zen-browser.url  = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";

    catppuccin.url   = "github:catppuccin/nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      imports = [ ./lib/mk-hosts.nix ];
    };
}
```

- [ ] **Step 2: Update the lock file**

Run: `nix flake lock`
Expected: adds `flake-parts`, `nix-darwin`, `nixos-hardware` to `flake.lock`.

- [ ] **Step 3: Evaluate the flake**

Run: `nix flake check --no-build`
Expected: no errors. (It may warn about unused inputs — that's fine.)

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock
git commit -m "refactor: rewrite flake.nix with flake-parts + multi-host wiring"
```

---

### Task 11: Verify equivalence of built system closure

**Files:** (none modified)

- [ ] **Step 1: Build the refactored system closure**

Run:
```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.naptop.config.system.build.toplevel \
  | tee .new-toplevel
```
Expected: prints a `/nix/store/...-nixos-system-naptop-26.05...` path.

- [ ] **Step 2: Diff against baseline with nvd**

Run:
```bash
nix shell nixpkgs#nvd -c nvd diff "$(cat .baseline-toplevel)" "$(cat .new-toplevel)"
```
Expected: `No version or selection state changes.` (or empty diff).

If there ARE differences, inspect them. Acceptable: ordering-only changes,
`/etc/nixos-version` metadata. Unacceptable: any added/removed service,
package, or changed config file content. If unacceptable differences appear,
STOP and investigate before proceeding.

- [ ] **Step 3: Spot-check a few files**

Run:
```bash
diff -r "$(cat .baseline-toplevel)/etc" "$(cat .new-toplevel)/etc" | head -50
```
Expected: empty output, or only trivial differences.

- [ ] **Step 4: Clean up scratch files**

Run:
```bash
rm .new-toplevel
```

---

### Task 12: Remove old top-level config files

**Files:**
- Delete: `configuration.nix`
- Delete: `home.nix`
- Delete: `hardware-configuration.nix`

- [ ] **Step 1: Remove the files**

Run:
```bash
git rm configuration.nix home.nix hardware-configuration.nix
```

- [ ] **Step 2: Re-verify the flake still builds**

Run:
```bash
nix build --no-link .#nixosConfigurations.naptop.config.system.build.toplevel
```
Expected: builds successfully (cached, instant).

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor: remove legacy flat-layout files"
```

---

### Task 13: Add skeletons for nas, darwin, foreign hosts

**Files:**
- Create: `hosts/nixos/nas/default.nix`
- Create: `hosts/foreign/jie@server/default.nix`
- Modify: `lib/mk-hosts.nix` — register `nas` and `jie@server`

- [ ] **Step 1: Write `hosts/nixos/nas/default.nix` (skeleton)**

```nix
# NAS host — NixOS on bare metal. Flesh out when hardware is provisioned.
{ ... }:
let user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../profiles/nas.nix
  ];

  networking.hostName = "nas";

  users.users.${user.me.username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
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

- [ ] **Step 2: Write `hosts/foreign/jie@server/default.nix`**

```nix
# Standalone home-manager config for the Ubuntu server.
# Activate with: home-manager switch --flake .#jie@server
{ ... }:
let user = import ../../../users/jie.nix;
in {
  imports = [
    ../../../modules/home/common
    ../../../modules/home/linux
  ];

  home.username = user.me.username;
  home.homeDirectory = "/home/${user.me.username}";
}
```

- [ ] **Step 3: Update `lib/mk-hosts.nix` to register them**

Replace the `flake.nixosConfigurations` / commented-out section with:
```nix
in {
  flake.nixosConfigurations = {
    naptop = mkNixos [ ../hosts/nixos/naptop ];
    nas    = mkNixos [ ../hosts/nixos/nas ];
  };

  flake.homeConfigurations = {
    "jie@server" = mkHome "x86_64-linux" [ ../hosts/foreign/jie@server ];
  };

  # flake.darwinConfigurations.<macname> = mkDarwin [ ../hosts/darwin/<macname> ];
}
```

- [ ] **Step 4: Check that every host evaluates**

Run:
```bash
nix flake check --no-build
```
Expected: no errors. All three configs (`naptop`, `nas`, `jie@server`) should
evaluate.

- [ ] **Step 5: Dry-build each skeleton**

Run:
```bash
nix build --no-link --dry-run \
  .#nixosConfigurations.nas.config.system.build.toplevel
nix build --no-link --dry-run \
  .#homeConfigurations."jie@server".activationPackage
```
Expected: both succeed (they'll want to fetch deps but should not error out on
evaluation).

- [ ] **Step 6: Commit**

```bash
git add hosts/nixos/nas hosts/foreign lib/mk-hosts.nix
git commit -m "refactor: add nas + jie@server host skeletons"
```

---

### Task 14: Activate refactored config on the live laptop

**Files:** (none modified)

- [ ] **Step 1: Switch to the new system**

Run:
```bash
sudo nixos-rebuild switch --flake .#naptop
```
Expected: activation succeeds; no errors. The activation message should say
"activating the configuration..." and finish cleanly.

- [ ] **Step 2: Smoke test the live system**

Manually verify each of these still works (one session):
- Open GNOME / log in cleanly.
- Open Ghostty terminal.
- Caps Lock tap → Esc; Caps Lock hold → Ctrl (via kanata).
- fcitx5 input method toggles (Ctrl+Space).
- Audio plays (pipewire).
- Close laptop lid → locks (does not suspend/crash).
- `nix run .#` or built-in commands still work.

- [ ] **Step 3: Clean up baseline file**

Run:
```bash
rm -f .baseline-toplevel
```

- [ ] **Step 4: Final commit (if any changes)**

```bash
git status
# Only expected output: nothing to commit.
```

---

## Self-review notes

**Spec coverage:**
- Layout ✓ (Tasks 2, 6, 9, 13)
- flake-parts wiring ✓ (Tasks 8, 10, 13)
- `lib/mk-hosts.nix` helpers ✓ (Task 8)
- `users/jie.nix` with theme centralization ✓ (Task 2; consumed in Tasks 7, 9, 13)
- Migration preserves behavior ✓ (Tasks 3–7, 9; verified in Task 11)
- Skeletons for nas / darwin / foreign ✓ (Task 13; darwin left as `.gitkeep` + commented hook — no hostname yet)
- Testing/verification ✓ (Tasks 1, 11, 14)
- No secrets / no overlays / no devshell ✓ (absent by design)

**Potential gotcha:** Step 2 of Task 2 uses `mkdir users` then `mv`. Simpler
is `mkdir -p users && <write file>`. Engineer should just write the file
directly to `users/jie.nix` after `mkdir -p users`.
