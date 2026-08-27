# Load the agenix-decrypted key set into the SSH agent at login (launchd on
# macOS, systemd on Linux). Desktop-only: headless boxes reach the same keys
# through the file pinning in ssh-identities.nix, and have no login session to
# hang an agent off.
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
