{ buildPythonPackage
, pymavlink
, progressbar2
, pkg-src
}:
buildPythonPackage rec {
    pname = "mavlog_utils";
    version = "0.0.0";
    propagatedBuildInputs = [
        pymavlink
        progressbar2
    ];
    src = pkg-src;
}
