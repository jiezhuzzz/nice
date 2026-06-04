# age-encrypted secrets decrypted at activation time using the host's
# SSH host key (see age.identityPaths). Each secret lands at
# /run/agenix/<name> with the owner/mode specified here.
_: let
  user = import ../../../users/jie.nix;
in {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets.github-ssh-key = {
    file = ../../../secrets/ssh/github.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.git-signing-key = {
    file = ../../../secrets/ssh/git-signing.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.chameleon-ssh-key = {
    file = ../../../secrets/ssh/chameleon.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.lab-ssh-key = {
    file = ../../../secrets/ssh/lab.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.rclone-gdrive-token = {
    file = ../../../secrets/rclone/gdrive.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.rclone-box-token = {
    file = ../../../secrets/rclone/box.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
}
