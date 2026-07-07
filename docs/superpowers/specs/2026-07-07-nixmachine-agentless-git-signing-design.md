# Agent-Free Git Identity on nixmachine (Design)

**Status:** approved · **Date:** 2026-07-07 · **Host:** nixmachine

## Problem

Git commit signing and GitHub push on nixmachine depend on the SSH agent
*forwarded* from a desktop. `modules/home-manager/common/git.nix` sets
`user.signingkey = "key::ssh-ed25519 …"`, whose `key::` prefix makes git pull the
private key from the agent; push auth uses the same forwarded key. A detached
tmux/shpool session outlives the SSH connection backing the forward, so
`SSH_AUTH_SOCK` goes stale and `git commit -S` / `git push` fail. Agent
forwarding cannot serve a fully-detached session — a persistent local key is
required.

## Goal / Non-goals

- **Goal:** signing + push work on nixmachine with **no agent**, using the
  existing `github-ssh-key` + `git-signing-key` deployed via agenix.
- **Non-goal (deferred):** goku/vegeta (foreign, standalone home-manager). They
  need the agenix home-manager module plus a per-host bootstrap identity to
  decrypt; that gets its own spec later.
- **Non-goal:** changing the signing identity. The same key is reused, so the
  existing `allowedSigners`/`signingPubkey` and "Verified" status are unchanged.
- **Non-goal:** touching the desktops' agent-based flow. They keep `key::` +
  keys loaded into the agent via `ssh-identities.nix`.

## Approach

Deploy the two existing agenix secrets to nixmachine and switch *nixmachine's*
git/ssh from agent-based to file-based:

- **Same key** → one identity across machines; existing `allowedSigners` stays
  valid.
- **File-based ssh signing** (`user.signingkey = <private-key path>`) needs no
  agent — git's `ssh-keygen -Y sign -f <file>` signs with the key directly.
- **Least privilege** — nixmachine decrypts only the two git secrets, not the
  desktops' full secret set.

## Components

### 1. Recipients — `secrets/secrets.nix`

Add nixmachine's host pubkey and make it a recipient for **only** the two git
secrets:

```nix
nixmachine = "ssh-ed25519 AAAA… (from /etc/ssh/ssh_host_ed25519_key.pub)";
# …
"ssh/github.age".publicKeys      = allRecipients ++ [nixmachine];
"ssh/git-signing.age".publicKeys = allRecipients ++ [nixmachine];
# all other secrets stay = allRecipients (nixmachine NOT added)
```

Then re-encrypt those two `.age` files (manual — see Prerequisites). nixmachine
is deliberately *not* added to `allHosts`, so it never gains the lab/home/
chameleon/rclone secrets.

### 2. System side (NixOS) — `modules/nixos/agenix-git.nix` (new)

Declares just the two secrets so agenix decrypts them at activation via the host
key to `/run/agenix/`, readable by `jie`:

```nix
{user, ...}: {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  age.secrets.github-ssh-key = {
    file = ../../secrets/ssh/github.age;
    owner = user.me.username; group = "users"; mode = "0400";
  };
  age.secrets.git-signing-key = {
    file = ../../secrets/ssh/git-signing.age;
    owner = user.me.username; group = "users"; mode = "0400";
  };
}
```

The agenix NixOS module is already injected by `lib/mk-hosts.nix`. This is scoped
to the two keys rather than importing the desktops' `modules/nixos/secrets.nix`
(which decrypts *every* secret and would force nixmachine to be a recipient for
all of them).

### 3. Home side (jie) — `modules/home-manager/common/git-agentless-signing.nix` (new)

Overrides the agent-based signing/auth with the decrypted files:

```nix
{lib, ...}: {
  programs.git.settings.user.signingkey = lib.mkForce "/run/agenix/git-signing-key";
  programs.ssh.settings."github.com" = {
    IdentityFile = "/run/agenix/github-ssh-key";
    IdentitiesOnly = true;
  };
}
```

`lib.mkForce` beats the `key::` default in `git.nix`. `gpg.format = ssh` and
`commit.gpgsign = true` (from `git.nix`) are unchanged.

### Wiring — `profiles/homelab.nix`

`homelab.nix` (the NixOS homelab-server profile, nixmachine-only today) imports
the system module and adds the home module to jie's imports:

```nix
{user, ...}: {
  imports = [../modules/nixos/agenix-git.nix];
  home-manager.users.${user.me.username}.imports = [
    ./home/server.nix
    ../modules/home-manager/common/git-agentless-signing.nix
  ];
}
```

Keeping the wiring in `homelab.nix` means a *future* homelab host would also get
agent-free git — but it would first need to be added as a recipient in
`secrets.nix`, so the coupling is explicit and safe (a non-recipient host fails
to decrypt loudly at activation).

## Manual prerequisites (user — cannot be done from this environment)

1. On nixmachine: `cat /etc/ssh/ssh_host_ed25519_key.pub` → paste the pubkey into
   `secrets.nix`.
2. After `secrets.nix` is edited, re-encrypt the two files from a machine holding
   a current recipient's *private* key (a desktop, or the `password-manager` key):
   `nix run github:ryantm/agenix -- -r` (rekey all), or `-e ssh/github.age` and
   `-e ssh/git-signing.age` individually.

Re-encryption requires an existing recipient private key, which this environment
does not hold.

## Verification

- `sudo nixos-rebuild switch --flake .#nixmachine` activates cleanly;
  `/run/agenix/{github-ssh-key,git-signing-key}` exist, owned `jie`, mode `0400`.
- On nixmachine in a **detached** tmux (no forwarded agent — `unset SSH_AUTH_SOCK`):
  - `git commit -S --allow-empty -m 'signing test'` succeeds.
  - `git log --show-signature -1` shows a good signature against the unchanged
    `allowedSigners`.
  - `ssh -T git@github.com` authenticates; a `git push` to a scratch branch works.

## Risks / notes

- The decrypted private key must be **passphrase-free** for non-interactive
  signing — the existing agenix key already is (it's agent-loaded today).
- `/run/agenix` is tmpfs; keys are re-decrypted each activation and never persist
  unencrypted on disk across reboots.
- `ssh-keygen -Y sign` requires the private key file to be tight-permissioned;
  `0400` owned by `jie` satisfies this.
