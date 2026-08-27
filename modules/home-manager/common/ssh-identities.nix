# SSH identity pinning for every host jie logs in from, desktop or headless.
# Keys are decrypted by agenix to /run/agenix/ (see the platform secrets
# modules); this pins each destination to its key file, which is what makes
# auth work on headless boxes where a detached tmux/shpool outlives the
# forwarded agent. Desktops additionally load the set into an agent — see
# ssh-agent-keys.nix. The base host blocks (HostName, User, ProxyJump) live in
# ssh.nix.
#
# Agent forwarding policy: only the Chameleon hosts (user `cc`: tacc +
# 10.52.*.*, set in ssh.nix) forward the agent — you hop between reserved
# bare-metal nodes and clone repos there. Everything else inherits
# `ForwardAgent no` from the `*` block. Forwarding into other boxes (esp.
# home-LAN machines like nixmachine) is what leaves a stale $SSH_AUTH_SOCK
# behind when the session drops, which then hangs github auth.
_: {
  programs.ssh.settings."github.com" = {
    IdentityFile = "/run/agenix/github-ssh-key";
    IdentitiesOnly = true;
    # Never consult the SSH agent for GitHub: auth is pinned to the agenix
    # key above, and a stale/forwarded agent socket ($SSH_AUTH_SOCK) makes
    # every `git@github.com` operation hang instead of using the key.
    IdentityAgent = "none";
  };
  # The homelab forge, on the same personal key as github.com — one identity
  # registered in both places. Agent bypassed for the reason given above.
  programs.ssh.settings."git.jiezhu.me" = {
    IdentityFile = "/run/agenix/github-ssh-key";
    IdentitiesOnly = true;
    IdentityAgent = "none";
  };
  programs.ssh.settings."tacc" = {
    IdentityFile = "/run/agenix/chameleon-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."10.52.*.*" = {
    IdentityFile = "/run/agenix/chameleon-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."uchicago" = {
    HostName = "linux.cs.uchicago.edu";
    User = "jiezhu";
    IdentityFile = "/run/agenix/lab-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."goku vegeta" = {
    ProxyJump = "uchicago";
    User = "jiezzz";
    IdentityFile = "/run/agenix/lab-ssh-key";
    IdentitiesOnly = true;
  };
  # nixmachine over the tailnet (MagicDNS name) — same home key as the LAN
  # block below, but works from anywhere the tailnet is up.
  programs.ssh.settings."nixmachine" = {
    HostName = "nixmachine.taile3de9d.ts.net";
    User = "jie";
    IdentityFile = "/run/agenix/home-ssh-key";
    IdentitiesOnly = true;
  };
  programs.ssh.settings."192.168.86.*" = {
    User = "jie";
    IdentityFile = "/run/agenix/home-ssh-key";
    IdentitiesOnly = true;
  };
}
