_: {
  # Run-time linker shim so unpatched, dynamically-linked binaries (e.g. tools
  # fetched by language toolchains, VS Code / Cursor remote servers, prebuilt
  # release binaries) can find an ld.so and the usual libraries under
  # /run/current-system/sw/share/nix-ld/lib.
  #
  # Wired into the mkNixos builder in lib/mk-hosts.nix so every NixOS host gets
  # it, rather than repeated per host. Left at the default library set; add
  # programs.nix-ld.libraries here if a specific binary needs more.
  programs.nix-ld.enable = true;
}
