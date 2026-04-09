# SSH client config. The github.com identity file is decrypted by agenix
# to /run/agenix/github-ssh-key; we expose it at the conventional
# ~/.ssh/github_ed25519 path via an out-of-store symlink so ssh config
# and tooling see a normal $HOME path.
{config, ...}: {
  home.file.".ssh/github_ed25519".source =
    config.lib.file.mkOutOfStoreSymlink "/run/agenix/github-ssh-key";

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
      identityFile = "~/.ssh/github_ed25519";
      identitiesOnly = true;
    };
  };
}
