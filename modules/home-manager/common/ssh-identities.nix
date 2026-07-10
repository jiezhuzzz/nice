# SSH identity pinning + agent auto-load for personal desktop machines.
# Keys are decrypted by agenix to /run/agenix/ (see the platform secrets
# modules); this pins each destination to its key and loads the whole set
# into the agent at login (launchd on macOS, systemd on Linux).
#
# Agent forwarding policy: only the Chameleon hosts (user `cc`: tacc +
# 10.52.*.*, set in ssh.nix) forward the agent — you hop between reserved
# bare-metal nodes and clone repos there. Everything else inherits
# `ForwardAgent no` from the `*` block. Forwarding into other boxes (esp.
# home-LAN machines like nixmachine) is what leaves a stale $SSH_AUTH_SOCK
# behind when the session drops, which then hangs github auth.
{
  lib,
  pkgs,
  ...
}: let
  keys = [
    "/run/agenix/github-ssh-key"
    "/run/agenix/git-signing-key"
    "/run/agenix/chameleon-ssh-key"
    "/run/agenix/lab-ssh-key"
    "/run/agenix/home-ssh-key"
  ];
in {
  programs.ssh.settings."github.com" = {
    IdentityFile = "/run/agenix/github-ssh-key";
    IdentitiesOnly = true;
    # Never consult the SSH agent for GitHub: auth is pinned to the agenix
    # key above, and a stale/forwarded agent socket ($SSH_AUTH_SOCK) makes
    # every `git@github.com` operation hang instead of using the key.
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
  programs.ssh.settings."192.168.86.*" = {
    User = "jie";
    IdentityFile = "/run/agenix/home-ssh-key";
    IdentitiesOnly = true;
  };

  launchd.agents.ssh-add-keys = lib.mkIf pkgs.stdenv.isDarwin {
    enable = true;
    config = {
      Label = "com.user.ssh-add-keys";
      ProgramArguments = ["/usr/bin/ssh-add"] ++ keys;
      RunAtLoad = true;
    };
  };

  systemd.user.services.ssh-add-keys = lib.mkIf pkgs.stdenv.isLinux {
    Unit.Description = "Load SSH keys into agent";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.openssh}/bin/ssh-add ${lib.concatStringsSep " " keys}";
    };
    Install.WantedBy = ["default.target"];
  };
}
