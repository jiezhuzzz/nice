# flake.lock is generated, and hand-editing it is worse than useless: every
# entry carries a narHash, so an edited revision either fails to verify or
# silently pins something that was never fetched. The agent reaches for it
# because a lock file *looks* like editable JSON, which is exactly why the
# refusal has to name the regenerating command.
#
# This one matches on Edit|Write rather than Bash, so it reads file_path
# instead of a command line (and needs no commandGuardPreamble).
{pkgs}: let
  inherit (import ./lib.nix {inherit pkgs;}) mkGuardHook;
in
  mkGuardHook "claude-flake-lock-hook" ''
    path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

    case "$path" in
      */flake.lock | flake.lock)
        deny "flake.lock is generated — never edit it by hand, since each entry carries a narHash that will no longer match. Regenerate it instead: 'nix flake update' rewrites every input, 'nix flake update <input>' bumps just one (for example 'nix flake update nixpkgs'). To change where an input points, edit the inputs block in flake.nix and let the lock follow."
        ;;
    esac
  ''
