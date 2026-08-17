# Reminder: the comment policy (agent-context.nix) is soft context the model
# drifts from mid-session; this replays it the moment an edit lands
# comment-heavy. Deliberately PostToolUse, not a PreToolUse deny — whether a
# given comment is legitimate needs judgement a script does not have, so the
# edit stands and the model is asked to reread its own comments against the
# policy. One added comment stays silent: that is usually the legitimate
# kind, and a reminder that fires on every comment would just be tuned out.
#
# Token cost only accrues on trigger: injected context stays in the
# conversation and is resent with every later request, so the reminder is
# kept to one line pointing at the policy already in context, and a
# per-session cooldown bounds how often it can fire at all.
''
  path=$(jq -r '.tool_input.file_path // ""' <<<"$input")

  # Prose and data formats, where leading #/*/-- lines are content
  # (markdown headings, list bullets, diff context), not comments.
  case "$path" in
    *.md | *.txt | *.rst | *.json | *.jsonl | *.csv | *.lock | *.patch | *.diff) exit 0 ;;
  esac

  if [ "$(jq -r '.tool_name' <<<"$input")" = "Write" ]; then
    new=$(jq -r '.tool_input.content // ""' <<<"$input")
    old=""
  else
    new=$(jq -r '.tool_input.new_string // ""' <<<"$input")
    old=$(jq -r '.tool_input.old_string // ""' <<<"$input")
  fi

  # Requiring whitespace after the marker skips #include, #!/ shebangs and
  # --flag continuation lines while keeping every comment the agent actually
  # writes, which always puts a space after the marker.
  count_comments() {
    grep -Ec '^[[:space:]]*(#|//|/\*|\*|--)([[:space:]]|$)' <<<"$1" || true
  }

  added=$(($(count_comments "$new") - $(count_comments "$old")))
  ((added >= 2)) || exit 0

  marker="''${XDG_RUNTIME_DIR:-/tmp}/claude-comment-reminder.$(jq -r '.session_id // "unknown"' <<<"$input")"
  [ -z "$(find "$marker" -mmin -20 2>/dev/null)" ] || exit 0
  touch "$marker"

  remind "This edit added $added comment lines. Recheck them against the comment policy in your context: keep only what the code cannot say (external constraint, non-obvious invariant, deliberate deviation, safety, TODO:/FIXME:/HACK:/SAFETY:), and silently remove the rest with a follow-up edit."
''
