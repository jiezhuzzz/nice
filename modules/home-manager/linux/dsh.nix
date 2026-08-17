# dsh — the DeepSeek Harness (github:deepseek-ai/deepseek-harness). nixmachine
# only, serving its browser UI at https://dsh.jiezhu.me through caddy (the `dsh`
# entry in modules/nixos/web-services.nix). No authentication of its own and the
# agent runs commands as jie, so the tailnet is the whole access control — never
# a LAN port or a non-loopback bind. Credentials are runtime state: set the
# provider key in the UI's Settings → Models.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # `dsh plugin` forwards to pnpm inside the profile dir, so pnpm has to be on
  # dsh's PATH. Wrapped rather than added to home.packages globally.
  dsh = pkgs.symlinkJoin {
    name = "dsh-${llmAgents.dsh.version}";
    paths = [llmAgents.dsh];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/dsh --prefix PATH : ${lib.makeBinPath [pkgs.pnpm]}
    '';
    inherit (llmAgents.dsh) meta;
  };

  port = 3080;
  vhost = "dsh.jiezhu.me";

  # systemd user units read none of home.sessionVariables, so both consumers
  # take these from here.
  dshEnv = {
    DSH_HOME = "${config.xdg.dataHome}/dsh";
    DSH_TELEMETRY_DISABLED = "1";
  };
in {
  home.packages = [dsh];

  home.sessionVariables = dshEnv;

  systemd.user.services.dsh-web = {
    Unit = {
      Description = "dsh web — DeepSeek Harness browser UI";
      Documentation = ["https://github.com/deepseek-ai/deepseek-harness"];
      After = ["network.target"];
    };

    Service = {
      # --trusted-host is not optional behind caddy: dsh fences /api on the Host
      # and Origin it is reached through, so the forwarded `Host: dsh.jiezhu.me`
      # draws a 403 on every API call while / still serves the UI.
      ExecStart = lib.concatStringsSep " " [
        "${dsh}/bin/dsh web"
        "--host 127.0.0.1"
        "--port ${toString port}"
        "--trusted-host ${vhost}"
      ];
      # The initial workspace root the agent is sandboxed to.
      WorkingDirectory = "%h";
      Environment = lib.mapAttrsToList (name: value: "${name}=${value}") dshEnv;
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = ["default.target"];
  };
}
