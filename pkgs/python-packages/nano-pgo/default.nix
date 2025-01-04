{ callPackage, pytestCheckHook, buildPythonPackage, numpy, scipy, plotly, sympy
, symforce, scikit-sparse, matplotlib, pkg-src }:
callPackage ../pythonPkgFromScript.nix {
  pname = "nano_pgo";
  version = "1.0.0";
  description =
    "For an education purpose, from-scratch, single-file, python-only pose-graph optimization implementation";
  script-file = "${pkg-src}/nano_pgo.py";
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs =
    [ numpy scipy sympy symforce scikit-sparse plotly matplotlib ];
  checkPkgs = [ ];
  longDescription = ''
    [Repository](https://github.com/gisbi-kim/nano-pgo/tree/main)

    Alternative open-source Python-based prototyping library to [pyceres](./pyceres.md).
    This isn't maintained by me; I just maintain a build of it for convenience.
    See below for some usage examples:

    - TODO
  ''; # ^^^^ TODO examples from scratchpad
}
