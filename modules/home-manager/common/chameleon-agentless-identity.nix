# Point the Chameleon hosts at the agenix-decrypted key file rather than a
# forwarded agent, so reservations driven from a detached tmux/shpool keep
# authenticating after the session that carried the agent goes away. The base
# host blocks (HostName, User, ProxyJump) stay in ssh.nix; desktops pin the
# same key from ssh-identities.nix instead.
_: {
  programs.ssh.settings."tacc" = {
    IdentityFile = "/run/agenix/chameleon-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."10.52.*.*" = {
    IdentityFile = "/run/agenix/chameleon-ssh-key";
    IdentitiesOnly = true;
  };
}
