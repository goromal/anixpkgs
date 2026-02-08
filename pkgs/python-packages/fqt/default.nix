{
  callPackage,
  pytestCheckHook,
  buildPythonPackage,
  click,
}:
callPackage ../pythonPkgFromScript.nix {
  pname = "fqt";
  version = "1.0.0";
  description = "Four-quadrant tasking.";
  script-file = ./fqt.py;
  inherit pytestCheckHook buildPythonPackage;
  propagatedBuildInputs = [ click ];
  checkPkgs = [ ];
  longDescription = ''
    This little CLI tool will suggest classes of activities to do based on configured priorities and preferences.

    Example config file:

    ```
    Framework Learning:25
    Programming Projects:25
    The Arts:10
    Fun:10
    Family:30
    ```
  '';
}
