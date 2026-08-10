# Shared machinery for the guard hooks beside this file. A plain value file
# (not a home-manager module), loaded with `import ./lib.nix {inherit pkgs;}`
# — the users/jie.nix pattern.
{pkgs}: let
  inherit (pkgs) lib;
in {
  # A bare `permissions.deny` entry tells the agent only that something was
  # refused, never what to do instead — so it improvises, and the usual
  # improvisation is to rewrite the job in shell rather than to reach for the
  # tool that was actually wanted. Each guard beside this file denies the same
  # commands but hands back the corrected command line, which is the part that
  # redirects it. Verified against claude-code 2.1.222: a PreToolUse hook is
  # consulted before the permission rules, so this reason is what the model
  # sees, and `permissions.deny` (settings.nix) stays on purely as a backstop
  # for a script failing open.
  #
  # Deliberately `command` hooks, not `prompt` ones: they run on every single
  # tool call, so they must be free and instant, and none of these questions
  # needs judgement. Deliberately not rewriting hooks either (PreToolUse can
  # silently swap the command via updatedInput) — a rewrite leaves the agent
  # reading output from a command it did not write, which is its own debugging
  # trap. Refusing and naming the fix keeps its picture of the shell honest.
  #
  # The wire format is identical for all of them, so it lives here once. Note
  # that silence means "allow": any guard that errors fails open, which is the
  # reason the coarse `permissions.deny` list is kept alongside these.
  #
  # `keywords` drives a fork-free prefilter: the payload is substring-matched
  # before paying for jq. The keywords are a conservative superset of what the
  # accurate checks in `text` can match (JSON escaping never touches these
  # plain words), so a false positive only costs falling through to them —
  # while the common case, a payload with no trigger word anywhere, exits
  # without a single fork.
  mkGuardHook = name: keywords: text:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [pkgs.jq];
      text =
        ''
          input=$(cat)

          case "$input" in
            ${lib.concatMapStringsSep " | " (k: "*${lib.escapeShellArg k}*") keywords}) ;;
            *) exit 0 ;;
          esac

          deny() {
            jq -nc --arg reason "$1" \
              '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
            exit 0
          }
        ''
        + text;
    };

  # Prepended by the guards that read a command line rather than a file path.
  # `sep` matches a word only in *command position*: start of the line, or after
  # a ; & | or ( separator. This is what stops a guard tripping over its own
  # advice — in `uv run python -c ...` and in `nix develop -c python x.py` the
  # word `python` follows an ordinary argument rather than a separator, so
  # neither matches.
  commandGuardPreamble = ''
    cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
    sep='(^|[;&|(])[[:space:]]*'
  '';
}
