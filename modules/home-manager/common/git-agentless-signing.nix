# Agent-free git signing for headless hosts: point the signing key at its
# agenix-decrypted file instead of the SSH agent, so `git commit -S` survives a
# detached tmux/shpool. Overrides the agent-based `key::` signingkey from
# modules/home-manager/common/git.nix. The key is unchanged, so the existing
# allowedSigners still verifies these signatures. The matching ssh auth pinning
# for github and the forge lives in ssh-identities.nix, which these hosts also
# import. Only for hosts that decrypt the secrets to /run/agenix.
{lib, ...}: {
  programs.git.settings.user.signingkey = lib.mkForce "/run/agenix/git-signing-key";
}
