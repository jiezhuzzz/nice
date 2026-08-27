# Lean, headless NixOS profile for homelab boxes (e.g. nixmachine): user
# `jie` gets the standalone-server home-manager toolkit (profiles/home/server.nix),
# wired through the NixOS home-manager module so the two never drift. On top of
# that base, this profile decrypts jie's personal key set (modules/nixos/secrets.nix,
# the same module the desktops use) and pins ssh and git signing at the files
# under /run/agenix rather than a forwarded agent — so github, the forge, the
# lab and Chameleon all keep authenticating from a detached tmux/shpool, where
# no agent survives. It also carries what server.nix's gdrive/box mounts need
# from the system side (modules/nixos/rclone.nix). Boot, storage, networking
# and the user account stay with the host.
{user, ...}: {
  imports = [
    ../modules/nixos/secrets.nix
    ../modules/nixos/rclone.nix
  ];

  home-manager.users.${user.me.username}.imports = [
    ./home/server.nix
    ../modules/home-manager/common/ssh-identities.nix
    ../modules/home-manager/common/git-agentless-signing.nix
  ];
}
