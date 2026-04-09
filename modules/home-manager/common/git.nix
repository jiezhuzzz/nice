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
  # Expose the signing key under ~/.ssh/ via an out-of-store symlink to
  # the agenix-decrypted file, so git sees a conventional $HOME path.
  home.file.".ssh/github_signing".source =
    config.lib.file.mkOutOfStoreSymlink "/run/agenix/git-signing-key";

  programs.git = {
    enable = true;
    settings = {
      user.name = user.me.fullname;
      user.email = user.me.email;
      # SSH commit signing, private key decrypted by agenix and symlinked
      # into ~/.ssh/github_signing by home-manager.
      user.signingkey = "${config.home.homeDirectory}/.ssh/github_signing";
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
