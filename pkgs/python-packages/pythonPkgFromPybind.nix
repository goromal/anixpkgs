{ pname
, version
, description
, stdenv
, pkg-src
, cppNativeBuildInputs
, cppBuildInputs
, cppTarget ? null
, pybind11
, python
, pythonOlder
, buildPythonPackage
, propagatedBuildInputs
}:
let
    copyTarget = if cppTarget != null then cppTarget else "${pname}*";
    pyboundPkg = stdenv.mkDerivation {
        name = "${pname}-pybind-build";
        inherit version;
        src = pkg-src;
        nativeBuildInputs = cppNativeBuildInputs;
        buildInputs = [ pybind11 ] ++ cppBuildInputs;
        # TODO kind of hacky--should find a more secure way to grab the built library
        installPhase = ''
            mkdir -p $out/lib
            cp -r ${copyTarget} $out/lib
        '';
    };
    pyboundTarget = "${pyboundPkg}/lib/${pname}*";
    pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in buildPythonPackage rec {
    inherit pname;
    inherit version;
    src = ./pkgTemplate/.;
    disabled = pythonOlder "3.6";
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
        cp ${pyboundTarget} $out/${pythonLibDir}/${pname}/
        chmod -R 777 $out/${pythonLibDir}
    '';
}
