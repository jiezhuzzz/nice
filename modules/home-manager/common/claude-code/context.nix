# Soft guidance injected into every session — Claude Code's user-level
# CLAUDE.md equivalent. The prose is shared with codex.nix.
let
  sections = import ../agent-context.nix;
in {
  programs.claude-code.context = sections.python + "\n" + sections.lineWrapping + "\n" + sections.commentPolicy + "\n" + sections.nixDevEnvironments;
}
