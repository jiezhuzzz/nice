# SSH Configuration Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean up SSH key management — remove symlink indirection, point identity pinning directly at agenix paths, and auto-load all 3 keys into the SSH agent at login.

**Architecture:** Remove `home.file` symlinks from both desktop profiles, update `identityFile` references to use `/run/agenix/` paths directly, and add platform-specific agent auto-loading (launchd on macOS, systemd on NixOS).

**Tech Stack:** Nix (nix-darwin, NixOS, home-manager, agenix)

---

### Task 1: Update `darwin-desktop.nix`

**Files:**
- Modify: `profiles/darwin-desktop.nix:83-95`

**Reference — current code (lines 83-95):**
```nix
    # Agenix-managed SSH key symlinks and identity pinning
    home.file.".ssh/github_ed25519".source =
      config.lib.file.mkOutOfStoreSymlink "/run/agenix/github-ssh-key";
    home.file.".ssh/chameleon_ed25519".source =
      config.lib.file.mkOutOfStoreSymlink "/run/agenix/chameleon-ssh-key";
    programs.ssh.matchBlocks."github.com" = {
      identityFile = "~/.ssh/github_ed25519";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."tacc".identityFile = "~/.ssh/chameleon_ed25519";
    programs.ssh.matchBlocks."tacc".identitiesOnly = true;
    programs.ssh.matchBlocks."10.52.*.*".identityFile = "~/.ssh/chameleon_ed25519";
    programs.ssh.matchBlocks."10.52.*.*".identitiesOnly = true;
```

- [ ] **Step 1: Replace symlinks + identity pinning with direct agenix paths, add launchd agent**

Replace the entire block (lines 83-95) with:

```nix
    # SSH identity pinning (keys decrypted by agenix to /run/agenix/)
    programs.ssh.matchBlocks."github.com" = {
      identityFile = "/run/agenix/github-ssh-key";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."tacc" = {
      identityFile = "/run/agenix/chameleon-ssh-key";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."10.52.*.*" = {
      identityFile = "/run/agenix/chameleon-ssh-key";
      identitiesOnly = true;
    };

    # Auto-load SSH keys into macOS system agent at login
    launchd.agents.ssh-add-keys = {
      enable = true;
      config = {
        Label = "com.user.ssh-add-keys";
        ProgramArguments = [
          "/usr/bin/ssh-add"
          "/run/agenix/github-ssh-key"
          "/run/agenix/git-signing-key"
          "/run/agenix/chameleon-ssh-key"
        ];
        RunAtLoad = true;
      };
    };
```

- [ ] **Step 2: Verify nix evaluation**

Run: `nix eval .#darwinConfigurations.nixmini.system --no-write-lock-file 2>&1 | head -5`
Expected: no evaluation errors (should print a store path or derivation)

- [ ] **Step 3: Commit**

```bash
git add profiles/darwin-desktop.nix
git commit -m "refactor: clean up SSH config in darwin-desktop profile

Remove ~/.ssh symlinks, point identityFile at /run/agenix/ directly,
add launchd agent to auto-load all 3 keys into SSH agent at login."
```

---

### Task 2: Update `nixos-desktop.nix`

**Files:**
- Modify: `profiles/nixos-desktop.nix:91-103`

**Reference — current code (lines 91-103):**
```nix
    # Agenix-managed SSH key symlinks and identity pinning
    home.file.".ssh/github_ed25519".source =
      config.lib.file.mkOutOfStoreSymlink "/run/agenix/github-ssh-key";
    home.file.".ssh/chameleon_ed25519".source =
      config.lib.file.mkOutOfStoreSymlink "/run/agenix/chameleon-ssh-key";
    programs.ssh.matchBlocks."github.com" = {
      identityFile = "~/.ssh/github_ed25519";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."tacc".identityFile = "~/.ssh/chameleon_ed25519";
    programs.ssh.matchBlocks."tacc".identitiesOnly = true;
    programs.ssh.matchBlocks."10.52.*.*".identityFile = "~/.ssh/chameleon_ed25519";
    programs.ssh.matchBlocks."10.52.*.*".identitiesOnly = true;
```

- [ ] **Step 1: Replace symlinks + identity pinning with direct agenix paths, add systemd service**

Replace the entire block (lines 91-103) with:

```nix
    # SSH identity pinning (keys decrypted by agenix to /run/agenix/)
    programs.ssh.matchBlocks."github.com" = {
      identityFile = "/run/agenix/github-ssh-key";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."tacc" = {
      identityFile = "/run/agenix/chameleon-ssh-key";
      identitiesOnly = true;
    };
    programs.ssh.matchBlocks."10.52.*.*" = {
      identityFile = "/run/agenix/chameleon-ssh-key";
      identitiesOnly = true;
    };

    # Auto-load SSH keys into agent at login
    systemd.user.services.ssh-add-keys = {
      Unit.Description = "Load SSH keys into agent";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.openssh}/bin/ssh-add /run/agenix/github-ssh-key /run/agenix/git-signing-key /run/agenix/chameleon-ssh-key";
      };
      Install.WantedBy = ["default.target"];
    };
```

- [ ] **Step 2: Verify nix evaluation**

Run: `nix eval .#nixosConfigurations.nixps.config.system.build.toplevel --no-write-lock-file 2>&1 | head -5`
Expected: no evaluation errors

- [ ] **Step 3: Commit**

```bash
git add profiles/nixos-desktop.nix
git commit -m "refactor: clean up SSH config in nixos-desktop profile

Remove ~/.ssh symlinks, point identityFile at /run/agenix/ directly,
add systemd user service to auto-load all 3 keys into SSH agent at login."
```

---

### Task 3: Verify on current machine (macOS)

- [ ] **Step 1: Build and switch**

Run: `darwin-rebuild switch --flake .`
Expected: successful activation with no errors

- [ ] **Step 2: Verify launchd agent is loaded**

Run: `launchctl list | grep ssh-add`
Expected: shows the `com.user.ssh-add-keys` agent

- [ ] **Step 3: Verify keys are in agent**

Run: `ssh-add -l`
Expected: 3 keys listed (github, signing, chameleon)

- [ ] **Step 4: Verify git SSH push works**

Run: `ssh -T git@github.com`
Expected: `Hi jiezhuzzz! You've successfully authenticated`

- [ ] **Step 5: Verify git signing works**

Run: `echo test | git commit-tree HEAD^{tree} -S`
Expected: produces a signed commit object (no "Couldn't find key in agent" error)
