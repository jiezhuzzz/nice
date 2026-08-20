# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine): user
# `jie` gets the standalone-server home-manager toolkit (profiles/home/server.nix),
# wired through the NixOS home-manager module so the two never drift. On top of
# that base, this profile adds agent-free git signing: agenix decrypts jie's
# github + signing keys (modules/nixos/agenix-git.nix) and git/ssh point at the
# files instead of a forwarded agent (git-agentless-signing.nix), so signing and
# push survive a detached tmux/shpool. It also carries what server.nix's
# gdrive/box mounts need from the system side (modules/nixos/rclone.nix): the
# decrypted tokens, and the setuid fusermount3 that a non-root FUSE mount goes
# through. Boot, storage, networking and the user account stay with the host.
{user, ...}: {
  imports = [
    ../modules/nixos/agenix-git.nix
    ../modules/nixos/rclone.nix
  ];
  # The host key every agenix secret on this box decrypts with. Declared once
  # here rather than in each module above: identityPaths is a list option, so
  # two modules naming the same key concatenate rather than override, and age
  # then warns "duplicate identity file" for every secret on every activation.
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  home-manager.users.${user.me.username}.imports = [
    ./home/server.nix
    ../modules/home-manager/common/git-agentless-signing.nix
  ];
}
