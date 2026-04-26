---
name: conventional-git
description: Use whenever creating git commits or git branches. Enforces the Conventional Branch spec (https://conventional-branch.github.io/) and Conventional Commits 1.0.0 (https://www.conventionalcommits.org/en/v1.0.0/), AND splits a working tree's changes into separate commits per logical dimension — docs vs code, feature vs bug fix vs refactor, even when those dimensions live inside the same file. Apply this whenever the user says "commit", "branch", "push", "open a PR", or whenever you would otherwise produce a single catch-all commit.
---

# Conventional Git

Two specs apply to every commit and branch in this repo:

- **Conventional Commits 1.0.0** — message format
- **Conventional Branch** — branch name format

A change set must also be **split by dimension** before committing. One commit = one logical change. The most common failure mode is a single "update" commit that mixes docs, refactors, fixes, and features. Don't do that.

## Why this matters

Conventional commits aren't bureaucracy — they make `git log`, `git blame`, `git revert`, and changelog generation actually work. SemVer tools rely on `feat`/`fix`/`BREAKING CHANGE`. A commit that mixes a bug fix with a refactor is impossible to revert cleanly: you either lose the fix or keep the refactor. Splitting by dimension preserves the option to undo each piece independently. The same logic applies to branches: a clear prefix tells reviewers and CI what kind of change is on the branch before they read a line of code.

## Commit message format

```
<type>[optional scope][!]: <description>

[optional body]

[optional footer(s)]
```

### Types

This repo uses a deliberately small set — five types only. The standard `style`, `refactor`, `perf`, `test`, `build`, `revert` types are **not** used; fold them into the types below.

| Type | When to use |
|------|-------------|
| `feat` | New feature, experiment, method, model, or capability |
| `fix` | Bug fix — anything that corrects wrong behavior or output |
| `docs` | Docs only: READMEs, notebooks, paper notes, comments |
| `chore` | Everything else a human commits: deps, lockfiles, configs, refactors, formatting, regenerated outputs, plot tweaks |
| `ci` | **Automated commit produced by CI/CD** (bots, schedulers, release pipelines) — *not* changes to CI config files. CI-config edits go under `chore`. |

Types are case-insensitive but use lowercase by convention.

#### Mapping from the standard set

If you instinctively reach for one of the dropped types, use this:

- `style:` → `chore:` (formatting is maintenance)
- `refactor:` → `chore:` (no behavior change is maintenance)
- `perf:` → `fix:` if it corrects a real performance bug, otherwise `chore:`
- `test:` → `chore(test):` if test-only, else fold into the `feat:`/`fix:` it accompanies
- `build:` → `chore:`
- `revert:` → `chore: revert <hash>` (or whatever type the original revert restores parity to)

#### Why `ci` means "by CI" here

The Conventional Commits convention uses `ci:` for changes to CI configuration. This repo overloads it to mean a commit *made by* automation — version bumps, scheduled lockfile updates, changelog regen, etc. The reasoning: human-authored CI-config tweaks are rare here and fit fine under `chore`, while automated commits show up often and benefit from being filterable in `git log`. Don't use `ci:` for a commit you typed yourself.

### Scope

Optional. A short noun in parentheses naming the area touched: `fix(parser):`, `feat(auth):`, `docs(readme):`. Use the same scope name consistently across commits in this repo (look at `git log` for prior scopes before inventing a new one).

### Description

- Imperative mood: "add", not "added" or "adds".
- Lowercase first letter.
- No trailing period.
- ≤72 chars when possible.

### Body

Free-form, separated from the description by a blank line. Explain **why**, not **what** — the diff already shows what. Wrap at ~72 chars.

### Footers

Git-trailer format (`Token: value` or `Token #value`). Tokens use hyphens, not spaces:

```
Refs: #123
Reviewed-by: Z
Co-authored-by: Name <email>
BREAKING CHANGE: <description>
```

`BREAKING CHANGE` (uppercase, with space) and `BREAKING-CHANGE` are equivalent and are the only footer that may contain spaces in the token.

### Breaking changes

Two equivalent ways to mark a breaking change — pick one:

1. `!` after the type/scope: `feat(api)!: drop support for v1 endpoints`
2. `BREAKING CHANGE:` footer with a description.

Either form bumps MAJOR in SemVer. Use `!` for short notes; use the footer when you need a paragraph.

### Examples

```
feat(auth): add JWT refresh endpoint
```

```
fix(parser): handle trailing comma in array literals

The tokenizer treated `,]` as an error. Now it emits a synthetic
nil node so downstream tools see a valid AST.

Refs: #482
```

```
chore(store)!: rename `Get` to `Fetch`

BREAKING CHANGE: All callers of store.Get must migrate to store.Fetch.
The old name leaked the implementation detail that data was already
in memory; Fetch is accurate for both cached and remote loads.
```

```
docs(readme): document NIX_CONFIG override for offline builds
```

```
chore(deps): bump flake.lock
```

```
ci: bump version to 0.4.2 [skip ci]
```

## Branch model

Trunk-based with tagged releases:

- **`main`** — the only long-lived branch. Always stable.
- **`feat/<desc>`**, **`fix/<desc>`**, **`chore/<desc>`** — short-lived branches that merge back into `main`.
- **Releases are tags on `main`**, e.g. `v0.4.2`. No `release/` branches, no `develop` branch.

### Branch prefixes

Three prefixes only — match the prefix to the *dominant* commit type on the branch:

| Prefix | Use for |
|--------|---------|
| `feat/` | New feature, experiment, method, model, capability |
| `fix/` | Bug fix |
| `chore/` | Everything else: deps, tooling, refactors, docs-only edits, formatting, configs |

The standard `hotfix/` and `release/` prefixes are intentionally not used. Urgency is signaled in the PR description, not the branch name. Releases are tags, not branches.

### Naming rules

- Lowercase letters, digits, and `-` only. No `_`, no spaces, no uppercase.
- No leading, trailing, or consecutive `-`.
- Concise but descriptive. Add a ticket id when applicable: `feat/issue-123-jwt-refresh`.

### Valid

- `feat/add-login-page`
- `fix/header-overflow`
- `chore/update-flake-lock`
- `chore/rewrite-readme`

### Invalid

- `Feat/Add-Login` (uppercase)
- `feat/new--login` (consecutive hyphens)
- `feat/-login` (leading hyphen)
- `fix/header_bug` (underscore)
- `release/v1.2.0` (use a tag instead: `git tag v1.2.0`)
- `hotfix/...` (use `fix/` and flag urgency in the PR)

### Releasing

```bash
git checkout main
git pull
git tag -a v0.4.2 -m "Release 0.4.2"
git push origin v0.4.2
```

If a release commit is needed (changelog, version bump), it should be authored by automation and committed as `ci: bump version to 0.4.2 [skip ci]` directly on `main`.

## Splitting a change set

This is the part most often skipped. Before committing, look at the working tree as a whole and ask: how many *independent* changes are mixed together here?

### The dimensions to split on

1. **Type**: docs vs feat vs fix vs chore. A README edit and a behavior fix are two commits, even if you made them in the same session.
2. **Scope/area**: changes to unrelated modules belong in separate commits even if they share a type.
3. **Intent within a single file**: one file can hold a bug fix, a small cleanup (`chore`), and a new feature. Each is its own commit.
4. **Behavior-changing vs behavior-preserving**: a `chore` cleanup and a `feat` must not share a commit — otherwise a future bisect can't tell which line caused a regression.
5. **Reversibility**: if you'd want the option to revert one piece without the other, split them.

### Workflow

1. **Survey**: run `git status` and `git diff` (and `git diff --staged` if anything is staged). Read every hunk.
2. **Classify**: for each hunk, write down its type and scope. Group hunks that share both.
3. **Order**: commit refactors and dependency bumps before features that build on them, so each commit compiles and tests pass on its own.
4. **Stage one group at a time**:
   - Whole file belongs to one group: `git add <path>`.
   - File holds multiple dimensions: `git add -p <path>` and stage only the relevant hunks. If hunks are too coarse, use `git add -p` and `s` (split), or `e` (edit) the hunk directly.
5. **Verify staging is clean**: `git diff --staged` should show *only* one logical change. If it doesn't, unstage with `git restore --staged <path>` and try again.
6. **Commit** with a Conventional Commits message.
7. **Repeat** until `git status` is clean.

### Worked example

`git status` shows:

```
M  src/parser.ts        # bug fix + a renamed helper (refactor)
M  README.md            # documented the new flag
M  src/cli.ts           # added the new --strict flag (feature)
M  package.json         # bumped a dep
```

Bad: one commit `update`. Good: four commits, in this order:

1. `chore(deps): bump zod to 3.23` — `package.json`
2. `chore(parser): rename validateNode helper` — the rename hunks in `src/parser.ts` (staged via `git add -p`). Behavior-preserving renames are `chore`, not `feat` or `fix`.
3. `fix(parser): handle trailing commas in arrays` — the remaining hunks in `src/parser.ts`
4. `feat(cli): add --strict flag` — `src/cli.ts` plus the README hunk that documents it

Note the README hunk goes with the feature, not as a separate `docs:` commit, because it documents the same change in the same PR. A README edit only earns its own `docs:` commit when it's independent of any code change.

## Workflow when the user says "commit"

1. Run `git status` and `git diff` to see everything.
2. Identify dimensions and propose a commit plan to the user *before* staging — a short numbered list of intended commits with their messages. This catches misclassifications early.
3. Once the user approves (or if they've delegated the call), stage and commit each group in turn.
4. After the last commit, run `git status` to confirm the tree is clean.

## Workflow when the user asks for a new branch

1. Determine the dominant change type — `feat`, `fix`, or `chore`. Anything that isn't a new feature or a bug fix is `chore`.
2. Pick a kebab-case description, ≤5 words.
3. `git checkout -b <prefix>/<description>` from an up-to-date `main`.
4. Confirm with the user if the branch will mix multiple dominant types — usually that's a sign it should be two branches and two PRs.

## Common mistakes

- **One catch-all "update" commit** — the spec exists precisely to prevent this. Always split.
- **Staging whole files when only some hunks belong** — use `git add -p`.
- **`feat:` for a behavior-preserving change** — if behavior is unchanged, it's `chore:`, not `feat:`.
- **`fix:` for a cleanup that happens to touch buggy-looking code** — only commits that actually change observable behavior to fix a bug are `fix:`.
- **`ci:` for human-edited CI config** — that's `chore:` (or `chore(ci):`). `ci:` is reserved for commits authored by automation.
- **Branch prefix mismatched with commits** — a `feat/` branch full of `fix:` commits is a smell; rename or reclassify. Helper commits (`chore:`, `docs:`) are fine alongside the dominant type.
- **Creating a `release/` or `hotfix/` branch** — this repo doesn't use them. Tag releases on `main`; flag urgent fixes in the PR description.
- **Uppercase or underscores in branch names** — silently breaks tooling that assumes the spec.
