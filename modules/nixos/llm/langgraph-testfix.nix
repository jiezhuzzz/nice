# nixpkgs workaround (remove once fixed upstream): langgraph 1.2.6's derivation
# tries to disable the flaky `test_error_handler_resumes_after_crash_multiple_nodes`
# race-condition test, but does it two ways wrong:
#   1. it's in `disabledTestPaths` as a `file::test` node-id, yet that attr emits
#      `pytest --ignore=<path>`, which only accepts real paths — so pytest never
#      matches it and the test still runs;
#   2. it's guarded to aarch64 only, while nixmachine is x86_64.
# The test then intermittently fails the build (`assert 0 == 1`), which blocks
# langchain -> open-webui, and the outputs aren't on cache.nixos.org so it must
# build from source. Deselect the test by name via `disabledTests` (matched with
# `-k "not ..."`, path-independent) so it's skipped on every platform.
# `pythonPackagesExtensions` applies the override to all python package sets, so
# langchain/open-webui consume the patched langgraph.
_: {
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pyfinal: pyprev: {
            langgraph = pyprev.langgraph.overridePythonAttrs (old: {
              disabledTests =
                (old.disabledTests or [])
                ++ ["test_error_handler_resumes_after_crash_multiple_nodes"];
            });
          })
        ];
    })
  ];
}
