{ callPackage, pytestCheckHook, buildPythonPackage }:
callPackage ../pythonPkgFromScript.nix {
  pname = "sunnyside";
  version = "1.0.0";
  description = "Make scrambled eggs.";
  script-file = ./sunnyside.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ ];
  checkPkgs = [ ];
  longDescription = ''
    ```
    usage: sunnyside [-h] target shift key

    Make some scrambled eggs.

    positional arguments:
    target      File target.
    shift       Shift amount.
    key         Scramble key.

    optional arguments:
    -h, --help  show this help message and exit
    ```
  '';
}
