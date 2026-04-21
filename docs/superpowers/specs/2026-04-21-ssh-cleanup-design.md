# SSH Configuration Cleanup

## Problem

The current SSH setup has several issues:

1. Key symlinks (`~/.ssh/github_ed25519`, etc.) are an unnecessary indirection layer over `/run/agenix/` paths
2. The git signing key is never loaded into the SSH agent, so `key::` lookups may fail
3. No automatic key loading into the SSH agent at login
4. Identity pinning is duplicated across `darwin-desktop.nix` and `nixos-desktop.nix`

## Goals

- SSH to servers using the correct key per host
- Git SSH push to GitHub using the dedicated GitHub key
- Git commit/tag signing using the dedicated signing key (via SSH agent)
- Signing key forwarded to chameleon (10.52.*) via agent forwarding
- All keys auto-loaded into the SSH agent at login
- No unnecessary symlinks

## Design

### Key inventory (unchanged)

| Key (agenix name)      | Purpose              | Used by              |
|------------------------|----------------------|----------------------|
| `github-ssh-key`       | GitHub SSH auth      | SSH client           |
| `git-signing-key`      | Git commit signing   | Git via SSH agent    |
| `chameleon-ssh-key`    | TACC cluster access  | SSH client           |

### `ssh.nix` (common) -- no changes

Stays as base config: global defaults and match block connection routing (github.com, tacc, 10.52.*).

### `git.nix` -- no changes

The `key::` prefix and `gpg.format = "ssh"` are already correct. Once the signing key is in the agent, everything works.

### `darwin-desktop.nix` -- changes

1. **Remove symlinks:** Delete both `home.file.".ssh/github_ed25519"` and `home.file.".ssh/chameleon_ed25519"` entries.

2. **Update identity pinning** to reference agenix paths directly:
   ```nix
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
   ```

3. **Auto-load keys into macOS system SSH agent at login** via `launchd.agents`:
   ```nix
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

### `nixos-desktop.nix` -- changes

Same as darwin-desktop.nix for steps 1 and 2.

3. **Auto-load keys via systemd user service:**
   ```nix
   systemd.user.services.ssh-add-keys = {
     Unit.Description = "Load SSH keys into agent";
     Service = {
       Type = "oneshot";
       ExecStart = "${pkgs.openssh}/bin/ssh-add /run/agenix/github-ssh-key /run/agenix/git-signing-key /run/agenix/chameleon-ssh-key";
     };
     Install.WantedBy = ["default.target"];
   };
   ```

### Server profile -- no changes

Chameleon receives the signing key via agent forwarding from the desktop (10.52.* already has `forwardAgent = true`). No local key management needed.

## What stays duplicated

The identity pinning and agent auto-loading appear in both desktop profiles. This is acceptable because:
- The agent mechanism differs per platform (launchd vs systemd)
- The profiles are the natural place for platform-specific key management
- The duplication is small (~15 lines) and intentional
