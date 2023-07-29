{ callPackage
, pytestCheckHook
, buildPythonPackage
, click
}:
callPackage ../pythonPkgFromScript.nix {
    pname = "fqt";
    version = "1.0.0";
    description = "Four-quadrant tasking.";
    script-file = ./fqt.py;
    inherit pytestCheckHook buildPythonPackage;
    propagatedBuildInputs = [ click ];
    checkPkgs = [];
    longDescription = ''
    ```bash
    Usage: fqt [OPTIONS] COMMAND [ARGS]...

    Four-quadrants tasking tools.

    Options:
    --config-file PATH  Path to the config file.  [default:
                        /data/andrew/fqt/config]
    --log-file PATH     Path to the log file.  [default: /data/andrew/fqt/log]
    --help              Show this message and exit.

    Commands:
    analyze  Analyze past task performance.
    task     Propose a task for the day.
    ```

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
