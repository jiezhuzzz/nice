# age-encrypted secrets decrypted at activation time using the host's
# SSH host key (see age.identityPaths). Each secret lands at
# /run/agenix/<name> with the owner/mode specified here.
{...}: let
  user = import ../../../users/jie.nix;
in {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets.github-ssh-key = {
    file = ../../../secrets/github-ssh-key.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.git-signing-key = {
    file = ../../../secrets/git-signing-key.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };

  age.secrets.chameleon-ssh-key = {
    file = ../../../secrets/chameleon-ssh-key.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
}
