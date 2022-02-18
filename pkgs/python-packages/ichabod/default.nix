{ callPackage
, pytestCheckHook
, buildPythonPackage
, pystemd
, veryprettytable
, pyperclip
}:
# TODO requires command `sudo apt install deluged deluge-console`
callPackage ../pythonPkgFromScript.nix {
    pname = "ichabod";
    version = "1.0.0";
    description = "Friend of the headless horseman.";
    script-file = ./ichabod.py;
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [
        pystemd
        veryprettytable
        pyperclip
    ];
}
