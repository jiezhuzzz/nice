# Guard: Python runs through uv, never a bare interpreter or pip.
''
  if [[ "$cmd" =~ $sep(uv[[:space:]]+pip|pip3?)([[:space:]]|$) ]]; then
    deny "Installing with pip is not how this machine does Python. For a standalone script, declare dependencies inline with PEP 723 script metadata and run it with 'uv run script.py' — 'uv add --script script.py <pkg>' edits that block for you. Inside a project, use 'uv add <pkg>'. Do not fall back to writing the task in shell instead; uv is installed and is the supported path."
  fi

  if [[ "$cmd" =~ $sep(python3?)([[:space:]]|$) ]]; then
    # `python -c` / `-m` / `--version` keep the interpreter and gain a `uv
    # run` prefix; `python script.py` drops it, since uv picks the
    # interpreter itself from the script's own metadata.
    if [[ "$cmd" =~ $sep(python3?)[[:space:]]+- ]]; then
      suggestion=$(sed -E "s@(^|[;&|(][[:space:]]*)python3?[[:space:]]@\1uv run python @g" <<<"$cmd")
    else
      suggestion=$(sed -E "s@(^|[;&|(][[:space:]]*)python3?[[:space:]]@\1uv run @g" <<<"$cmd")
    fi
    deny "Run Python through uv, never a bare interpreter. Use this instead: $suggestion — if it needs third-party packages, declare them inline with PEP 723 first ('uv add --script <script> <pkg>'). Do not work around this by rewriting the task in shell, awk or a heredoc; uv is installed and is the supported path."
  fi
''
