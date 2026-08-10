# Wires the guard hooks into Claude Code's PreToolUse list. Each guard lives
# in its own file beside this one; the shared mkGuardHook machinery and the
# rationale for guarding at all are in lib.nix.
{pkgs, ...}: let
  uvOnlyHook = import ./uv-only.nix {inherit pkgs;};
  nixDeclarativeHook = import ./nix-declarative.nix {inherit pkgs;};
  flakeLockHook = import ./flake-lock.nix {inherit pkgs;};
in {
  # Hooks matching the same tool run in parallel and cannot see each other,
  # so each guard has to stand alone — the first one to deny wins, and the
  # rest are wasted work rather than a conflict.
  programs.claude-code.settings.hooks.PreToolUse = [
    {
      matcher = "Bash";
      hooks = [
        {
          type = "command";
          command = "${uvOnlyHook}/bin/claude-uv-only-hook";
          timeout = 5;
        }
        {
          type = "command";
          command = "${nixDeclarativeHook}/bin/claude-nix-declarative-hook";
          timeout = 5;
        }
      ];
    }
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = "${flakeLockHook}/bin/claude-flake-lock-hook";
          timeout = 5;
        }
      ];
    }
  ];
}
