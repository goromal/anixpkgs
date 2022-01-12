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
        preConfigure = ''
        cmakeFlags="$cmakeFlags --no-warn-unused-cli"
        '';
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
        sed -i 's|_tmptitle|${pname}|g' __version__.py
        sed -i 's|_tmpdescription|${description}|g' __version__.py
        sed -i 's|_tmpversion|${version}|g' __version__.py
    '';
    postInstall = ''
        cp ${pyboundTarget} $out/${pythonLibDir}/
        chmod -R 777 $out/${pythonLibDir}
    '';
}
