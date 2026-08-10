# The Nix counterpart of the pip rule, for the same reason: an imperative
# install is the one thing that puts software on this machine without a line
# in this flake describing it. It also hides — nothing in a `git status`
# shows that `nix-env -i` ever ran, so the drift is only found much later, on
# a host that was supposed to be reproducible.
#
# The corrected command depends on why the tool is wanted, so the reason names
# both: `nix shell nixpkgs#pkg -c ...` for a one-off (the common case — the
# tool is needed for the next command and never again), or a module edit plus
# a rebuild when it should persist.
''
  # nix-env is only imperative when it installs; `nix-env -q`, for instance,
  # just queries and is harmless, so the install flags are matched too.
  if [[ "$cmd" =~ $sep"nix-env"[[:space:]] ]] && [[ "$cmd" =~ [[:space:]](-i|-iA|-ie|--install)([[:space:]]|$) ]]; then
    deny "nix-env installs imperatively, which this machine does not do — nothing in the NICE flake would record that the package exists. If the tool is needed for one command, run it ephemerally: 'nix shell nixpkgs#<pkg> -c <command>'. If it should persist, add it to the right module (home.packages, or environment.systemPackages for a system tool) and rebuild. Do not substitute curl-pipe-sh or a download into ~/.local/bin either."
  fi

  if [[ "$cmd" =~ $sep"nix"[[:space:]]+profile[[:space:]]+(add|install)([[:space:]]|$) ]]; then
    deny "'nix profile' installs imperatively, which this machine does not do — nothing in the NICE flake would record that the package exists. If the tool is needed for one command, run it ephemerally: 'nix shell nixpkgs#<pkg> -c <command>'. If it should persist, add it to the right module (home.packages, or environment.systemPackages for a system tool) and rebuild."
  fi
''
