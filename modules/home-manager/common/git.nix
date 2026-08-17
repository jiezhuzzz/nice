{pkgs, ...}: let
  user = import ../../../users/jie.nix;
  signingPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqAEvgo0iyCrzXC2i03sTHQIAgSbzwPp9U44fIOGXMu";
  allowedSigners = pkgs.writeText "allowed_signers" ''
    ${user.me.email} ${signingPubkey}
  '';
in {
  programs.git = {
    enable = true;
    lfs.enable = true;
    attributes = [
      "* text=auto"
      # Encrypted secrets — never diff or merge.
      "*.age binary"
      "*.png binary"
      "*.jpg binary"
      "*.jpeg binary"
      "*.gif binary"
      "*.ico binary"
      "*.webp binary"
      "*.avif binary"
      "*.heic binary"
      "*.psd binary"
      "*.drawio binary"
      "*.mp3 binary"
      "*.mp4 binary"
      "*.mov binary"
      "*.webm binary"
      "*.wav binary"
      "*.flac binary"
      "*.zip binary"
      "*.tar binary"
      "*.tar.gz binary"
      "*.tgz binary"
      "*.gz binary"
      "*.bz2 binary"
      "*.xz binary"
      "*.zst binary"
      "*.7z binary"
      "*.rar binary"
      "*.exe binary"
      "*.dll binary"
      "*.so binary"
      "*.dylib binary"
      "*.a binary"
      "*.o binary"
      "*.pdb binary"
      "*.dmg binary"
      "*.iso binary"
      "*.pdf binary"
      "*.woff binary"
      "*.woff2 binary"
      "*.ttf binary"
      "*.otf binary"
      "*.eot binary"
      "*.md diff=markdown"
      "*.tex diff=tex"
      "*.py diff=python"
      "*.rb diff=ruby"
      "*.go diff=golang"
      "*.rs diff=rust"
      "*.css diff=css"
      "*.html diff=html"
    ];
    ignores = [
      ".DS_Store"
      ".codex/"
      ".claude/"
      ".agents/"
      ".direnv/"
      ".envrc.local"
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
