# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine): user
# `jie` gets the standalone-server home-manager toolkit (profiles/home/server.nix),
# wired through the NixOS home-manager module so the two never drift. On top of
# that base, this profile adds agent-free git signing: agenix decrypts jie's
# github + signing keys (modules/nixos/agenix-git.nix) and git/ssh point at the
# files instead of a forwarded agent (git-agentless-signing.nix), so signing and
# push survive a detached tmux/shpool. It also decrypts the rclone tokens
# (agenix-rclone.nix) that server.nix's gdrive/box mounts need — without them
# rclone-config.service cannot render a config and both mounts stay dead.
# Boot, storage, networking and the user account stay with the host.
{user, ...}: {
  imports = [
    ../modules/nixos/agenix-git.nix
    ../modules/nixos/agenix-rclone.nix
  ];
  home-manager.users.${user.me.username}.imports = [
    ./home/server.nix
    ../modules/home-manager/common/git-agentless-signing.nix
  ];
}
