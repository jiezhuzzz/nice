{
  config,
  pkgs,
  ...
}: let
  user = import ../../../users/jie.nix;
  signingPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqAEvgo0iyCrzXC2i03sTHQIAgSbzwPp9U44fIOGXMu";
  allowedSigners = pkgs.writeText "allowed_signers" ''
    ${user.me.email} ${signingPubkey}
  '';
in {
  programs.git = {
    enable = true;
    settings = {
      user.name = user.me.fullname;
      user.email = user.me.email;
      # SSH commit signing, private key decrypted by agenix.
      user.signingkey = "/run/agenix/git-signing-key";
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = toString allowedSigners;
      commit.gpgsign = true;
      tag.gpgsign = true;
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };
}
