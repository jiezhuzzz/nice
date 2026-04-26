# SSH client config — base settings shared by all hosts.
# Desktop machines additionally import ssh-keys.nix for local key paths.
_: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = false;
      addKeysToAgent = "yes";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
    };
    matchBlocks."github.com" = {
      hostname = "github.com";
      user = "git";
    };
    matchBlocks."tacc" = {
      hostname = "129.114.108.248";
      user = "cc";
    };
    matchBlocks."10.52.*.*" = {
      user = "cc";
      proxyJump = "tacc";
      forwardAgent = true;
    };
  };
}
