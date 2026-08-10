# Wires the guard snippets beside this file into Claude Code's PreToolUse
# list; machinery and rationale live in lib.nix.
{
  lib,
  pkgs,
  ...
}: let
  inherit (import ./lib.nix {inherit pkgs;}) mkGuardHook commandGuardPreamble;

  # Both Bash guards ride one binary, so the payload is read and jq-parsed
  # once per call. `deny` exits, so the first matching guard wins.
  bashGuard = mkGuardHook "claude-bash-guard" ["pip" "python" "nix-env" "profile"] (
    commandGuardPreamble
    + import ./uv-only.nix
    + "\n"
    + import ./nix-declarative.nix
  );

  flakeLockGuard = mkGuardHook "claude-flake-lock-hook" ["flake.lock"] (import ./flake-lock.nix);
in {
  programs.claude-code.settings.hooks.PreToolUse = [
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = lib.getExe bashGuard;
          timeout = 5;
        }
      ];
    }
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = lib.getExe flakeLockGuard;
          timeout = 5;
        }
      ];
    }
  ];
}
