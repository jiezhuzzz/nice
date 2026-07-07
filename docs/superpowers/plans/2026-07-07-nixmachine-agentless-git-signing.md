# Agent-Free Git Identity on nixmachine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy the existing `github-ssh-key` + `git-signing-key` to nixmachine via agenix and switch nixmachine's git/ssh from agent-based to file-based, so commit signing and GitHub push work in a detached tmux/shpool with no SSH agent.

**Architecture:** A scoped NixOS module declares the two agenix secrets (owner `jie`) so they decrypt to `/run/agenix/`; a home-manager module overrides git's signing key and github IdentityFile to those files; `profiles/homelab.nix` wires both. Recipients are added in `secrets/secrets.nix` and the two `.age` files re-encrypted (user-run). No new signing identity — the existing key/allowedSigners are reused.

**Tech Stack:** Nix flake, agenix (`ryantm/agenix`), home-manager, NixOS.

**Verification model:** Nix is declarative — each code task is verified with `nix eval` (the config resolves to the expected value). Re-encryption and `nixos-rebuild switch` happen on real hosts and are the user-run Task 4.

**Spec:** `docs/superpowers/specs/2026-07-07-nixmachine-agentless-git-signing-design.md`

**Commands run from the repo root** `/home/jie/Repos/nice`. All commits are signed (ssh-agent must be up).

---

### Task 1: NixOS module — declare the two agenix secrets for nixmachine

**Files:**
- Create: `modules/nixos/agenix-git.nix`
- Modify: `profiles/homelab.nix` (add the system `imports`)

- [ ] **Step 1: Create the module**

`modules/nixos/agenix-git.nix`:
```nix
# Decrypts jie's GitHub auth + git signing keys to /run/agenix so git works
# without an SSH agent (needed on headless boxes where the forwarded agent dies
# with a detached tmux/shpool). Scoped to just these two secrets — nixmachine is
# a recipient for only ssh/github.age + ssh/git-signing.age (see secrets/secrets.nix),
# not the full desktop secret set. Consumed by the agenix NixOS module that
# lib/mk-hosts.nix already injects.
{user, ...}: {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets.github-ssh-key = {
    file = ../../secrets/ssh/github.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
  age.secrets.git-signing-key = {
    file = ../../secrets/ssh/git-signing.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
}
```

- [ ] **Step 2: Wire the system import into `profiles/homelab.nix`**

Change the file from:
```nix
{user, ...}: {
  home-manager.users.${user.me.username}.imports = [./home/server.nix];
}
```
to:
```nix
{user, ...}: {
  imports = [../modules/nixos/agenix-git.nix];
  home-manager.users.${user.me.username}.imports = [./home/server.nix];
}
```

- [ ] **Step 3: Format**

Run: `nix fmt -- modules/nixos/agenix-git.nix profiles/homelab.nix`
Expected: `formatted … files`

- [ ] **Step 4: Verify the secrets are declared correctly (eval)**

Run:
```bash
git add modules/nixos/agenix-git.nix   # flakes only see tracked files
nix eval --raw ".#nixosConfigurations.nixmachine.config.age.secrets.git-signing-key.owner"
nix eval --raw ".#nixosConfigurations.nixmachine.config.age.secrets.github-ssh-key.owner"
nix eval --raw ".#nixosConfigurations.nixmachine.config.age.secrets.git-signing-key.file"
```
Expected:
- both `owner` calls print `jie`
- the `.file` call prints a `/nix/store/…-git-signing.age` path (proves the secret references the encrypted file)

- [ ] **Step 5: Commit**

```bash
git add modules/nixos/agenix-git.nix profiles/homelab.nix
git commit -m "feat(nixos): decrypt jie's github + signing keys on nixmachine"
```

---

### Task 2: Home-manager module — file-based signing + github IdentityFile

**Files:**
- Create: `modules/home-manager/common/git-agentless-signing.nix`
- Modify: `profiles/homelab.nix` (add the home-manager import)

- [ ] **Step 1: Create the module**

`modules/home-manager/common/git-agentless-signing.nix`:
```nix
# Agent-free git identity for headless hosts: point signing + github auth at the
# agenix-decrypted key files under /run/agenix instead of the SSH agent, so
# `git commit -S` and `git push` survive a detached tmux/shpool (no forwarded
# agent). Overrides the agent-based `key::` signingkey from
# modules/home-manager/common/git.nix. The key is unchanged, so the existing
# allowedSigners still verifies these signatures. Only for hosts that actually
# decrypt these secrets to /run/agenix (see modules/nixos/agenix-git.nix).
{lib, ...}: {
  programs.git.settings.user.signingkey = lib.mkForce "/run/agenix/git-signing-key";

  programs.ssh.settings."github.com" = {
    IdentityFile = "/run/agenix/github-ssh-key";
    IdentitiesOnly = true;
  };
}
```

- [ ] **Step 2: Wire the home-manager import into `profiles/homelab.nix`**

Change the `home-manager.users` line so jie also imports the new module:
```nix
{user, ...}: {
  imports = [../modules/nixos/agenix-git.nix];
  home-manager.users.${user.me.username}.imports = [
    ./home/server.nix
    ../modules/home-manager/common/git-agentless-signing.nix
  ];
}
```

- [ ] **Step 3: Format**

Run: `nix fmt -- modules/home-manager/common/git-agentless-signing.nix profiles/homelab.nix`
Expected: `formatted … files`

- [ ] **Step 4: Verify the override took effect (eval)**

Run:
```bash
git add modules/home-manager/common/git-agentless-signing.nix
b=".#nixosConfigurations.nixmachine.config.home-manager.users.jie"
nix eval --raw "$b.programs.git.settings.user.signingkey"
nix eval --raw "$b.programs.ssh.settings.\"github.com\".IdentityFile"
```
Expected:
- signingkey prints `/run/agenix/git-signing-key` (the file path — NOT the `key::ssh-ed25519 …` default), proving `mkForce` won.
- IdentityFile prints `/run/agenix/github-ssh-key`.

- [ ] **Step 5: Confirm the whole host still evaluates**

Run: `nix eval ".#nixosConfigurations.nixmachine.config.system.build.toplevel.drvPath" >/dev/null && echo OK`
Expected: `OK` (the full nixmachine config evaluates with both modules wired).

- [ ] **Step 6: Commit**

```bash
git add modules/home-manager/common/git-agentless-signing.nix profiles/homelab.nix
git commit -m "feat(home-manager): sign/push via agenix key files on nixmachine"
```

---

### Task 3: Add nixmachine as a recipient for the two git secrets

**Files:**
- Modify: `secrets/secrets.nix`

> **Requires user input:** nixmachine's host public key. Get it with, on nixmachine:
> `cat /etc/ssh/ssh_host_ed25519_key.pub`
> The implementer must pause and obtain this exact value before editing. Do NOT invent a key.

- [ ] **Step 1: Add nixmachine's host key and grant it the two git secrets**

In `secrets/secrets.nix`, add nixmachine to the host-keys block:
```nix
  nixmachine = "ssh-ed25519 AAAA…";  # <- the real value from the user
```
Then extend only the two git secrets' recipient lists (leave every other secret as `allRecipients`):
```nix
  "ssh/github.age".publicKeys = allRecipients ++ [nixmachine];
  "ssh/git-signing.age".publicKeys = allRecipients ++ [nixmachine];
```

- [ ] **Step 2: Verify the manifest still evaluates**

Run: `nix-instantiate --eval --strict secrets/secrets.nix >/dev/null && echo OK`
Expected: `OK` (no Nix syntax error; nixmachine is a valid recipient entry). This file is the agenix-CLI manifest, not consumed by the flake, so this eval is the check.

- [ ] **Step 3: Commit**

```bash
git add secrets/secrets.nix
git commit -m "chore(secrets): grant nixmachine the github + signing secrets"
```

---

### Task 4: Re-encrypt, deploy, and verify (USER-RUN — not a subagent task)

These steps decrypt/re-encrypt secrets and touch the live host; they can't run from the dev environment (no recipient private key here) or a subagent. Run them yourself.

- [ ] **Step 1: Re-encrypt the two secrets to include nixmachine**

From a machine that already holds a *current* recipient private key (a desktop, or wherever your `password-manager` key lives — nixmachine itself can't, it isn't yet a recipient of everything), in the repo root:
```bash
# Rekeys ALL secrets to match secrets/secrets.nix. Non-interactive.
nix run github:ryantm/agenix -- -r
# (Alternatively, to touch only the two files, re-save each in $EDITOR:
#   nix run github:ryantm/agenix -- -e ssh/github.age
#   nix run github:ryantm/agenix -- -e ssh/git-signing.age )
git add secrets/ssh/github.age secrets/ssh/git-signing.age
git commit -m "chore(secrets): re-encrypt github + signing keys for nixmachine"
```
Expected: the two `.age` files change; agenix reports success.

- [ ] **Step 2: Build & switch on nixmachine**

```bash
sudo nixos-rebuild switch --flake .#nixmachine
```
Expected: activates cleanly; then:
```bash
ls -l /run/agenix/git-signing-key /run/agenix/github-ssh-key
```
Expected: both exist, owner `jie`, mode `-r--------` (0400).

- [ ] **Step 3: Verify agent-free signing + push in a detached session**

On nixmachine, simulate "no forwarded agent":
```bash
env -u SSH_AUTH_SOCK git -C /tmp/scratch-repo commit -S --allow-empty -m "agentless signing test"
env -u SSH_AUTH_SOCK git -C /tmp/scratch-repo log --show-signature -1
```
Expected: the commit is created and `log --show-signature` shows `Good "git" signature for jiezhu@uchicago.edu` against the unchanged allowed-signers (no "gpg failed to sign" / no agent errors).

Then confirm GitHub auth works without the agent:
```bash
env -u SSH_AUTH_SOCK ssh -T git@github.com
```
Expected: `Hi <user>! You've successfully authenticated…` (auth via `/run/agenix/github-ssh-key`, not an agent).

---

## Self-Review

**Spec coverage:**
- Recipients + re-encrypt (spec §1) → Task 3 (recipient edit) + Task 4 Step 1 (re-encrypt) ✓
- System-side decryption, owner `jie`, scoped to two secrets (spec §2) → Task 1 ✓
- Home-side file-based signing + github IdentityFile (spec §3) → Task 2 ✓
- Wiring via `homelab.nix` (spec) → Tasks 1 & 2 Step 2 ✓
- Manual prerequisites (host pubkey, re-encrypt) → Task 3 note + Task 4 Step 1 ✓
- Verification (activation, detached-tmux signing/push) → Task 4 Steps 2–3 ✓

**Placeholder scan:** The only intentional blank is nixmachine's real host pubkey in Task 3 — flagged as required user input, not a code placeholder. All module code is complete.

**Type/path consistency:** `/run/agenix/git-signing-key` and `/run/agenix/github-ssh-key` are used identically in Task 1 (secret names → those runtime paths) and Task 2 (git/ssh references). Secret names `github-ssh-key` / `git-signing-key` match `secrets/definitions.nix`. Relative paths: `modules/nixos/agenix-git.nix` → `../../secrets/ssh/*.age` (correct from `modules/nixos/`); `profiles/homelab.nix` → `../modules/...` (correct from `profiles/`).
