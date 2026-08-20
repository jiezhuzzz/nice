# SSH client config — base settings shared by all hosts.
# Desktop machines additionally pin identity files (see *-desktop.nix profiles).
_: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "yes";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
      ControlMaster = "no";
      ControlPath = "~/.ssh/master-%r@%n:%p";
      ControlPersist = "no";
    };
    settings."github.com" = {
      HostName = "github.com";
      User = "git";
    };
    # The homelab forge (modules/nixos/forgejo/server.nix). Port 2222 because
    # git is served by Forgejo's own SSH server rather than the host's sshd —
    # without it the short `git.jiezhu.me:jie/repo` form would hit :22 and
    # land on nixmachine's shell account. Identity pinning is per-host, in
    # ssh-identities.nix (desktops) and git-agentless-signing.nix (headless).
    settings."git.jiezhu.me" = {
      User = "git";
      Port = 2222;
    };
    # Chameleon (user `cc`) is the ONLY place we forward the agent: you hop
    # from the tacc gateway onto reserved bare-metal nodes (10.52.*.*) and use
    # your keys there. No other host forwards — see ssh-identities.nix for why.
    settings."tacc" = {
      HostName = "129.114.108.248";
      User = "cc";
      ForwardAgent = true;
    };
    settings."10.52.*.*" = {
      User = "cc";
      ProxyJump = "tacc";
      ForwardAgent = true;
    };
  };
}
