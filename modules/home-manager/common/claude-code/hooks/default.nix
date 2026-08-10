# Wires the guard hooks into Claude Code's PreToolUse list. Each guard is a
# shell snippet in its own file beside this one; the shared machinery and the
# rationale for guarding at all live in lib.nix.
{
  lib,
  pkgs,
  ...
}: let
  inherit (import ./lib.nix {inherit pkgs;}) mkGuardHook commandGuardPreamble;

  # Both Bash guards ride one binary: hooks on the same matcher run as
  # separate processes that each read and jq-parse the identical payload, so
  # keeping them apart doubled the per-call cost of the hottest hook path for
  # nothing. Concatenation keeps first-deny-wins semantics — `deny` exits.
  bashGuard = mkGuardHook "claude-bash-guard" ["pip" "python" "nix-env" "profile"] (
    commandGuardPreamble
    + import ./uv-only.nix
    + "\n"
    + import ./nix-declarative.nix
  );

  flakeLockGuard = mkGuardHook "claude-flake-lock-hook" ["flake.lock"] (import ./flake-lock.nix);
in {
  # lib.getExe rather than a hand-written "${hook}/bin/<name>": the binary
  # name lives only in each mkGuardHook call above, so a rename cannot leave
  # a dangling command here — which would not fail eval, just silently fail
  # open at runtime.
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
