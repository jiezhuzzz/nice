---
description: Split the working tree into separate Conventional Commits via a subagent
argument-hint: "[why the changes were made — context for commit bodies]"
---

## Your task

Delegate to the **conventional-git** subagent. It surveys the working tree, splits it into one commit per logical change, and creates those commits.

**Do not run `git status`, `git diff`, or `git log` yourself.** Reading the diff in this session is exactly the cost this command exists to avoid — the subagent reads it in its own context, and only its report comes back here. Dispatch first, without looking.

Launch a single subagent with `subagent_type: conventional-git`. Its prompt must include:

1. The instruction to split and commit the current working tree.
2. `$ARGUMENTS` verbatim, if non-empty, introduced as context for the commit bodies.

The subagent sees only the repo — never this conversation. So if `$ARGUMENTS` is empty but earlier turns in this session explain *why* the changes were made (a bug being fixed, a rationale for a refactor, an issue number), summarize that into the prompt in two or three sentences. Commit bodies are supposed to explain why, and this is the only channel that carries it.

If `$ARGUMENTS` is empty and the session offers no rationale either, dispatch anyway. The subagent falls back to subject-line-only commits, which is the correct outcome rather than an invented body.

## After it returns

Relay the subagent's report: the commits it created and the final working-tree state. Surface its Notes verbatim if present — ambiguous type calls it resolved on its own, any file committed whole because per-hunk splitting failed, anything left uncommitted, and any hook or signing failure.

Add one line noting nothing was pushed, and that `git reset --soft HEAD~N` restores the tree if the split isn't what the user wanted.

Do not re-run the commits, amend them, or "improve" the messages afterward. If the user wants changes, they will say so.
