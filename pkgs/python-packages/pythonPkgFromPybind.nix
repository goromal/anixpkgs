{ pname
, version
, description
, stdenv
, pkg-src
, cppNativeBuildInputs
, cppBuildInputs
, cppSetup ? null
, cppTarget ? null
, hasTests ? false
, pybind11
, python
, pythonOlder
, pytestCheckHook
, buildPythonPackage
, propagatedBuildInputs
, checkPkgs
}:
let
    copyTarget = if cppTarget != null then cppTarget else "${pname}.cpython*";
    pyboundPkg = stdenv.mkDerivation {
        name = "${pname}-pybind-build";
        inherit version;
        src = pkg-src;
        nativeBuildInputs = cppNativeBuildInputs;
        buildInputs = [ pybind11 ] ++ cppBuildInputs;
        prePatch = if cppSetup != null then cppSetup else "";
        preConfigure = ''
        cmakeFlags="$cmakeFlags --no-warn-unused-cli"
        '';
        installPhase = ''
            mkdir -p $out/lib
            cp -r ${copyTarget} $out/lib
        '';
    };
    pyboundTarget = "${pyboundPkg}/lib/${pname}*";
    pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
    testsCpyCmd = if hasTests then ''
    cp ${pkg-src}/tests/* tests/
    '' else "";
in buildPythonPackage rec {
    inherit pname;
    inherit version;
    src = ./pkgTemplate/.;
    disabled = pythonOlder "3.6";
    inherit propagatedBuildInputs;
    doCheck = hasTests;
    checkInputs = [ pytestCheckHook ] ++ checkPkgs;
    prePatch = ''
        sed -i 's|_tmptitle|${pname}|g' __version__.py
        sed -i 's|_tmpdescription|${description}|g' __version__.py
        sed -i 's|_tmpversion|${version}|g' __version__.py
        ${testsCpyCmd}
    '';
    postInstall = ''
        cp ${pyboundTarget} $out/${pythonLibDir}/
        chmod -R 777 $out/${pythonLibDir}
    '';
}
