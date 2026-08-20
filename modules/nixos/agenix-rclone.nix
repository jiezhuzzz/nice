# Decrypts jie's rclone OAuth tokens to /run/agenix so the gdrive/box mounts in
# modules/home-manager/common/rclone.nix can render their config. Scoped to just
# these two secrets — nixmachine is a recipient for them plus ssh/github.age +
# ssh/git-signing.age (see secrets/secrets.nix), not the full desktop set that
# modules/nixos/secrets.nix decrypts.
#
# The attribute names have to stay in step with secrets/definitions.nix, which
# is what the darwin hosts decrypt these under: rclone.nix picks its token path
# by looking the secret up by name, so a rename here silently drops this host
# back to the hand-placed fallback path.
{user, ...}: {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets.rclone-gdrive-token = {
    file = ../../secrets/rclone/gdrive.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
  age.secrets.rclone-box-token = {
    file = ../../secrets/rclone/box.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
}
