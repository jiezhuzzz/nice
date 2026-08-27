# Decrypts jie's Chameleon Cloud key to /run/agenix so `ssh cc@...` works
# without an SSH agent, the same way agenix-git.nix does for git. Headless
# boxes drive reservations from a detached tmux/shpool, which outlives the
# forwarded agent that carried the key. age.identityPaths lives in
# profiles/homelab.nix, which imports this — see the note there.
{user, ...}: {
  age.secrets.chameleon-ssh-key = {
    file = ../../secrets/ssh/chameleon.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
}
