# System-level support for the rclone mounts that profiles/home/server.nix
# gives jie: the OAuth tokens they authenticate with, and the setuid
# fusermount3 they mount through.
#
# programs.fuse.enable is what puts a setuid fusermount3 in /run/wrappers/bin,
# which is where nixpkgs' fuse is compiled to look for its mount helper
# (-DFUSERMOUNT_DIR, set in pkgs/os-specific/linux/fuse/common.nix). Without it
# libfuse falls back to the plain copy in rclone's own closure, which carries
# no setuid bit, so mount(2) returns EPERM and every mount unit dies with
# "fusermount3: mount failed: Operation not permitted". Nothing in this repo
# had needed the wrapper before: the macOS hosts mount through fuse-t, and the
# standalone-home-manager servers run on distros that ship their own setuid
# helper, which leaves nixmachine as the first NixOS host to mount anything.
# userAllowOther stays off — these mounts are single-user and pass no
# allow_other.
#
# The tokens themselves come from modules/nixos/secrets.nix, which decrypts
# every entry in secrets/definitions.nix.
_: {
  programs.fuse.enable = true;
}
