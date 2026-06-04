{inputs, ...}: let
  user = import ../../../users/jie.nix;
in {
  imports = [inputs.agenix.darwinModules.default];

  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets.github-ssh-key = {
    file = ../../../secrets/ssh/github.age;
    owner = user.me.username;
    mode = "0400";
  };

  age.secrets.git-signing-key = {
    file = ../../../secrets/ssh/git-signing.age;
    owner = user.me.username;
    mode = "0400";
  };

  age.secrets.chameleon-ssh-key = {
    file = ../../../secrets/ssh/chameleon.age;
    owner = user.me.username;
    mode = "0400";
  };

  age.secrets.lab-ssh-key = {
    file = ../../../secrets/ssh/lab.age;
    owner = user.me.username;
    mode = "0400";
  };

  age.secrets.rclone-gdrive-token = {
    file = ../../../secrets/rclone/gdrive.age;
    owner = user.me.username;
    mode = "0400";
  };

  age.secrets.rclone-box-token = {
    file = ../../../secrets/rclone/box.age;
    owner = user.me.username;
    mode = "0400";
  };
}
