{ python
, pname
, description
, version
, propagatedBuildInputs
, pyexec
}:
let
    pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in python.pkgs.buildPythonPackage rec {
    inherit pname;
    inherit version;
    src = ./pkgTemplate/.;
    inherit propagatedBuildInputs;
    doCheck = false;
    prePatch = ''
        mv _tmp ${pname}
        sed -i 's|_tmp|${pname}|g' setup.py
        sed -i 's|_tmptitle|${pname}|g' ${pname}/__version__.py
        sed -i 's|_tmpdescription|${description}|g' ${pname}/__version__.py
        sed -i 's|_tmpversion|${version}|g' ${pname}/__version__.py
    '';
    postInstall = ''
        cp ${pyexec} $out/${pythonLibDir}/${pname}/
        chmod -R 777 $out/${pythonLibDir}
    '';
}