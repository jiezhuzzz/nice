# Soft guidance injected into every session — Claude Code's user-level
# CLAUDE.md equivalent. The prose lives in ../agent-context.nix, shared with
# codex.nix so both agents carry the same policies.
let
  sections = import ../agent-context.nix;
in {
  programs.claude-code.context = sections.python + "\n" + sections.lineWrapping + "\n" + sections.nixDevEnvironments;
}
