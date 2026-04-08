# SSH client config. The github.com identity file is decrypted by agenix
# at boot to /run/agenix/github-ssh-key (owned by this user).
{...}: {
  programs.ssh = {
    enable = true;
    # Opt out of the legacy implicit defaults; set our own "*" block below.
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = false;
      addKeysToAgent = "no";
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
      identityFile = "/run/agenix/github-ssh-key";
      identitiesOnly = true;
    };
  };
}
