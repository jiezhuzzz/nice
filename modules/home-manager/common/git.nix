{pkgs, ...}: let
  user = import ../../../users/jie.nix;
  signingPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqAEvgo0iyCrzXC2i03sTHQIAgSbzwPp9U44fIOGXMu";
  allowedSigners = pkgs.writeText "allowed_signers" ''
    ${user.me.email} ${signingPubkey}
  '';
in {
  programs.git = {
    enable = true;
    attributes = [
      "*.age binary"
    ];
    settings = {
      user.name = user.me.fullname;
      user.email = user.me.email;
      # key:: prefix tells git to find the matching private key in the
      # SSH agent — works with agent forwarding and local agents alike.
      user.signingkey = "key::${signingPubkey}";
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = toString allowedSigners;
      commit.gpgsign = true;
      tag.gpgsign = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      merge.conflictstyle = "zdiff3";
      diff.algorithm = "histogram";
      transfer.fsckobjects = true;
      fetch.fsckobjects = true;
      receive.fsckobjects = true;
      rebase.autosquash = true;
      rerere.enabled = true;
    };
  };
}
