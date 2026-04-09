{inputs, ...}: let
  user = import ../../../users/jie.nix;
in {
  imports = [inputs.agenix.darwinModules.default];

  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets.github-ssh-key = {
    file = ../../../secrets/github-ssh-key.age;
    owner = user.me.username;
    mode = "0400";
  };

  age.secrets.git-signing-key = {
    file = ../../../secrets/git-signing-key.age;
    owner = user.me.username;
    mode = "0400";
  };
}
