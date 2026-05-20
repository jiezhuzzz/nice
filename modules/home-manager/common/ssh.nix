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
