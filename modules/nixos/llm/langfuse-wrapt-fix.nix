# nixpkgs workaround (remove once fixed upstream): langfuse 4.0.2 pins
# `wrapt<2.0,>=1.14`, but nixpkgs ships wrapt 2.2.2. `pythonRuntimeDepsCheckHook`
# then fails the build with `wrapt<2.0,>=1.14 not satisfied by version 2.2.2`,
# which blocks langfuse -> litellm -> the litellm.service unit. The upper bound
# is just langfuse being conservative; relax it so the wheel accepts wrapt 2.x.
# `pythonPackagesExtensions` applies the override to all python package sets so
# litellm consumes the patched langfuse.
_: {
  nixpkgs.overlays = [
    (final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pyfinal: pyprev: {
            langfuse = pyprev.langfuse.overridePythonAttrs (old: {
              pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["wrapt"];
            });
          })
        ];
    })
  ];
}
