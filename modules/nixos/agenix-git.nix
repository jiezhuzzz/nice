# Decrypts jie's GitHub auth + git signing keys to /run/agenix so git works
# without an SSH agent (needed on headless boxes where the forwarded agent dies
# with a detached tmux/shpool). Scoped to just these two secrets — nixmachine is
# a recipient for only ssh/github.age + ssh/git-signing.age (see secrets/secrets.nix),
# not the full desktop secret set. Consumed by the agenix NixOS module that
# lib/mk-hosts.nix already injects. age.identityPaths lives in
# profiles/homelab.nix, which imports this — see the note there.
{user, ...}: {
  age.secrets.github-ssh-key = {
    file = ../../secrets/ssh/github.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
  age.secrets.git-signing-key = {
    file = ../../secrets/ssh/git-signing.age;
    owner = user.me.username;
    group = "users";
    mode = "0400";
  };
}
