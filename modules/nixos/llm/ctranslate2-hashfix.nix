# nixpkgs workaround (remove once fixed upstream / once nixpkgs-unstable advances
# past the broken pin): ctranslate2 4.8.1 is fetched from GitHub with
# fetchSubmodules, but the hash pinned in this nixpkgs revision
# (sha256-+82u+w08wGX0oh1wBaH/epI2IH7lxbvMThJEoGt0Kvk=) no longer matches what the
# fetcher produces (sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=, confirmed
# deterministic across two re-fetches). The stale hash fails the fixed-output
# derivation, which blocks faster-whisper -> open-webui, and the closure isn't on
# cache.nixos.org so it must build from source. Repin src to the actually-downloaded
# hash. python3Packages.ctranslate2 reuses this src via the alias
# `ctranslate2-cpp = pkgs.ctranslate2` (pkgs/top-level/python-packages.nix), so
# overriding the top-level package fixes both the C++ library and the python binding.
_: {
  nixpkgs.overlays = [
    (final: prev: {
      ctranslate2 = prev.ctranslate2.overrideAttrs (old: {
        src = old.src.overrideAttrs (_: {
          outputHash = "sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=";
        });
      });
    })
  ];
}
