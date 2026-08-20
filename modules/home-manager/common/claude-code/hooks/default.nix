# Wires the hook snippets beside this file into Claude Code's settings:
# guards into PreToolUse, reminders into PostToolUse. Machinery and
# rationale live in lib.nix.
{
  lib,
  pkgs,
  ...
}: let
  inherit (import ./lib.nix {inherit pkgs;}) mkGuardHook mkReminderHook commandGuardPreamble;

  githubViaGh = import ./github-via-gh.nix;

  # All three Bash guards ride one binary, so the payload is read and
  # jq-parsed once per call. `deny` exits, so the first matching guard wins.
  bashGuard = mkGuardHook "claude-bash-guard" ["pip" "python" "nix-env" "profile" "github"] (
    commandGuardPreamble
    + import ./uv-only.nix
    + "\n"
    + import ./nix-declarative.nix
    + "\n"
    + githubViaGh.fromCommand
  );

  flakeLockGuard = mkGuardHook "claude-flake-lock-hook" ["flake.lock"] (import ./flake-lock.nix);

  webFetchGuard = mkGuardHook "claude-webfetch-guard" ["github"] githubViaGh.fromUrl;

  commentReminder = mkReminderHook "claude-comment-reminder" (import ./comment-policy.nix);
in {
  programs.claude-code.settings.hooks.PostToolUse = [
    {
      matcher = "Edit|Write";
      hooks = [
        {
          type = "command";
          command = lib.getExe commentReminder;
          timeout = 5;
        }
      ];
    }
  ];

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
    {
      matcher = "WebFetch";
      hooks = [
        {
          type = "command";
          command = lib.getExe webFetchGuard;
          timeout = 5;
        }
      ];
    }
  ];
}
