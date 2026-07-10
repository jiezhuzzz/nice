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
    # Agent-free by design (see header): don't let a dead/forwarded agent
    # socket hang `git push` — auth uses the key file directly.
    IdentityAgent = "none";
  };
}
