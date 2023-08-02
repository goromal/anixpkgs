{ buildPythonPackage
, pkg-src
}:
buildPythonPackage rec {
    pname = "python_dokuwiki";
    version = "0.0.0";
    propagatedBuildInputs = [];
    doCheck = false;
    src = pkg-src;
    meta = {
        description = "Manage Dokuwiki via XMLRPC.";
        longDescription = ''
        [Third-party library](https://github.com/fmenabe/python-dokuwiki/tree/master) packaged in Nix as a dependency of [wiki-tools](./wiki-tools.md).
        '';
    };
}
