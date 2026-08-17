# Shared "soft guidance" sections for the coding agents, imported by
# claude-code/context.nix and codex.nix so both carry one set of policies.
# Each section is a complete markdown block; consumers join them with "\n".
{
  python = ''
    # Python

    - Always use `uv` to run Python scripts, never `python` or `python3` directly.
    - Run scripts with `uv run script.py`, never `python script.py`.
    - When writing a standalone Python script, declare its dependencies inline
      with PEP 723 (https://peps.python.org/pep-0723/) script metadata, then run
      it with `uv run script.py`. uv reads the metadata block, builds an
      ephemeral virtualenv with those deps, and runs the script — no separate
      install step, no project files:
      ```python
      # /// script
      # requires-python = ">=3.12"
      # dependencies = [
      #   "requests<3",
      #   "rich",
      # ]
      # ///
      ```
      Add deps to an existing inline script with
      `uv add --script script.py 'requests<3'` (uv edits the block for you).
      For a self-executing script, use the shebang `#!/usr/bin/env -S uv run --script`.
    - Do not use `pip install`, `pip3 install`, or `uv add` for standalone scripts. Inline the dependencies instead.
    - For Python projects (not standalone scripts), use `uv init`, `uv add`, and `uv run`.
    - Use `uv run` to execute any Python tooling (pytest, ruff, mypy, etc.).
  '';

  lineWrapping = ''
    # Line wrapping

    - Never hand-wrap text to a column width. Layout is the formatter's job, not something to do by hand.
    - Markdown: write each paragraph and each bullet as one line, however long, and let the editor soft-wrap it. Never insert a line break mid-sentence or at ~80 characters. Tables and fenced code blocks are content rather than prose — leave those laid out as written.
    - Code: never break a line just to hit a width, and never pad with spaces to align things into columns. Write it plainly and run the project's formatter — `nix fmt` (alejandra) here, otherwise whatever the repo configures: prettier, `ruff format`, `rustfmt`, `gofmt`.
    - The one exception is text no formatter reflows: comments and docstrings. Match the file being edited — where its comments wrap at ~80 columns, keep wrapping to match, since nothing will do it afterwards.
  '';

  commentPolicy = ''
    # Comment policy

    1. Prefer no comment.
    2. Never explain what the code does.
    3. Never restate names, types, control flow, or function behavior in prose.
    4. If a comment is necessary to understand the implementation, refactor first.
    5. Comments may only document information that cannot be represented in code: external constraints, non-obvious invariants, deliberate deviations from the obvious implementation, safety arguments, temporary technical debt.
    6. A prose comment must explain a constraint or decision originating outside the local code.
    7. Action comments must use one of: `TODO:`, `FIXME:`, `HACK:`, `SAFETY:`.
    8. Remove comments that become redundant after refactoring.
  '';

  nixDevEnvironments = ''
    # Nix dev environments

    - Most projects here are Nix flakes. When the project root has a `flake.nix` with a `devShell`, some commands need that dev shell's tools.
    - Do not assume the dev shell is active. It is active only when `$IN_NIX_SHELL` or `$DIRENV_DIR` is set, and several of these repos have no `.envrc` — a plain session then starts *outside* the dev shell, with its tools simply absent from `PATH`. Check rather than guess.
    - When a tool is missing, choose by where it lives. Listed in this project's `devShell`: `nix develop -c '<command>'`. Not listed there, which is the usual case for one-off utilities like `rg`, `strings` or `hexdump`: `nix shell nixpkgs#<package> -c '<command>'`, or `nix run nixpkgs#<package> -- <args>` when the package's own binary is all that is wanted. Each runs a fresh shell per invocation, so wrap every command — entering once does not persist.
    - Never install something to make a command work: no `nix-env -i`, no `nix profile add`, no `curl | sh`, no dropping a binary in `~/.local/bin`. A tool needed permanently belongs in a module in the NICE flake; everything else is ephemeral through `nix shell`.
    - `nix fmt` is the formatter for a flake that defines one, and it needs no dev shell — the flake supplies its own. In NICE it runs treefmt (alejandra, statix, shellcheck, shfmt, actionlint) across the tree.
    - `flake.lock` is generated. Never hand-edit it: regenerate with `nix flake update` for every input, or `nix flake update <input>` for one.
    - When a `flake.nix` devShell exists but there is no `.envrc`, suggest adding one containing `use flake` (then `direnv allow`) so it loads automatically — but do not create or commit the file.
  '';
}
