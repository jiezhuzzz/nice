# One entry per agenix secret: name → encrypted source file. Consumed by the
# platform secrets modules (modules/nixos/secrets.nix and
# modules/nix-darwin/secrets.nix), which decrypt each to /run/agenix/<name>.
# Recipients for the .age files live in ./secrets.nix (agenix CLI manifest).
{
  github-ssh-key = ./ssh/github.age;
  git-signing-key = ./ssh/git-signing.age;
  chameleon-ssh-key = ./ssh/chameleon.age;
  lab-ssh-key = ./ssh/lab.age;
  home-ssh-key = ./ssh/home.age;
  rclone-gdrive-token = ./rclone/gdrive.age;
  rclone-box-token = ./rclone/box.age;
}
