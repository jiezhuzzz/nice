{pkgs, ...}: {
  programs.atuin = {
    enable = true;
    # atuin 18.23.0's e2e tests drive bash, the pty proxy and the daemon through
    # a real pty; under the macOS build sandbox over a dozen of them time out.
    package =
      if pkgs.stdenv.hostPlatform.isDarwin
      then pkgs.atuin.overrideAttrs {doCheck = false;}
      else pkgs.atuin;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };
}
