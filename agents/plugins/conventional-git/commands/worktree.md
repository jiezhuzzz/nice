---
description: Create and switch into a git worktree on a Conventional Branch named branch
argument-hint: "<what you're about to work on>"
---

## Your task

Create a worktree on a convention-named branch and switch this session into it. `$ARGUMENTS` describes the work.

**Do this inline. Do not delegate to a subagent** — `EnterWorktree` called from a subagent switches only that agent's directory, not this session's, so delegating produces a worktree you are not in.

### 1. Pick the prefix

Exactly three are allowed. Match the *dominant* intent of the upcoming work:

| Prefix | Use for |
|--------|---------|
| `feat/` | New feature, experiment, method, model, capability |
| `fix/` | Bug fix |
| `chore/` | Everything else: deps, tooling, refactors, docs, formatting, configs |

`hotfix/` and `release/` are deliberately unavailable. Urgency belongs in the PR description; releases are tags on `main`, not branches.

### 2. Build the name

From `$ARGUMENTS`, write a description that is:

- lowercase letters, digits, and `-` only — no underscores, no uppercase, no spaces
- no leading, trailing, or consecutive `-`
- ≤5 words, concise but specific
- prefixed with a ticket id when one applies: `feat/issue-123-jwt-refresh`

The final name is `<prefix>/<description>` — for example `feat/add-jwt-refresh`, `fix/header-overflow`, `chore/update-flake-lock`.

If `$ARGUMENTS` is empty, ask what the work is rather than inventing a name.

### 3. Check the tree first

Run `git status --porcelain`. If it is **not** empty, stop and tell the user before creating anything.

This matters because the worktree branches from `origin/<default-branch>` by default (the `worktree.baseRef` setting, default `fresh`) — **not** from your current HEAD. Two consequences:

- Uncommitted changes stay behind in the current directory. They do not follow you.
- Local commits not yet pushed are also absent from the new worktree.

So offer the choice: `/commit` the work first, or proceed knowingly and leave it behind. Only continue once they have chosen.

### 4. Create and enter

```
EnterWorktree(name: "<prefix>/<description>")
```

This creates the worktree under `.claude/worktrees/`, creates the branch, and switches the session into it — one call, no separate `git worktree add` or `git checkout -b`.

`EnterWorktree` refuses to create a new worktree while the session is already in one. If that happens, report it and let the user decide: `ExitWorktree` first, or pass an existing worktree's `path` to switch instead.

### 5. Confirm

State the branch name, the worktree path, and that the session is now working inside it. Mention that `ExitWorktree` returns to the original directory — `keep` leaves the work on disk, `remove` deletes the worktree and branch.

Do not commit, push, or create a PR. This command only opens the workspace.
