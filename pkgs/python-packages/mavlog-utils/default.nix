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
    meta = {
        description = "Assorted tools for processing mavlink .bin logs.";
        longDescription = ''
        [Repository](https://github.com/goromal/mavlog-utils)
        '';
    };
}
