# Everything CI builds, as a flat attrset keyed by attribute path, so that
# nix-eval-jobs can evaluate the targets in parallel (see scripts/ci_build.py).
{
  # Subset of index.json package categories to include.
  categories ? [ ],
  # Include the build environments that the package categories share.
  envs ? false,
  # Select each package's `.doc` attribute (index.json `docs` flag) instead of
  # the package itself (index.json `ci` flag).
  docs ? false,
}:
let
  pkgs = import ../default.nix { };
  inherit (pkgs) lib;
  index = lib.importJSON ../index.json;
  byAttr = attr: lib.getAttrFromPath (lib.splitString "." attr) pkgs;
  categoryTargets =
    category:
    map (pkg: lib.nameValuePair pkg.attr (if docs then (byAttr pkg.attr).doc else byAttr pkg.attr)) (
      builtins.filter (pkg: if docs then pkg.docs else pkg.ci) index.pkgs.${category}
    );
  envTargets = lib.optionals envs [
    (lib.nameValuePair "clangStdenv" pkgs.clangStdenv)
    (lib.nameValuePair "python311" pkgs.python311)
    (lib.nameValuePair "python311.pkgs.pybind11" pkgs.python311.pkgs.pybind11)
    (lib.nameValuePair "php74" pkgs.php74)
  ];
in
builtins.listToAttrs (envTargets ++ lib.concatMap categoryTargets categories)
