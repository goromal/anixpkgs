{ pname
, version
, description
, script-file
, test-dir ? null
, pytestCheckHook
, buildPythonPackage
, propagatedBuildInputs
, checkPkgs
}:
let
    testsCpyCmd = if test-dir != null then ''
    cp ${test-dir}/* tests/
    '' else "";
in buildPythonPackage rec {
    inherit pname;
    inherit version;
    src = ./pkgTemplate/.;
    inherit propagatedBuildInputs;
    doCheck = (test-dir != null);
    checkInputs = [ pytestCheckHook ] ++ checkPkgs;
    preConfigure = ''
        mkdir ${pname}
        touch ${pname}/__init__.py
        cp ${script-file} ${pname}/cli.py
        sed -i 's|entry_points={}|entry_points={"console_scripts":["${pname}=${pname}.cli:main"]}|g' setup.py
        sed -i 's|_tmptitle|${pname}|g' __version__.py
        sed -i 's|_tmpdescription|${description}|g' __version__.py
        sed -i 's|_tmpversion|${version}|g' __version__.py
        ${testsCpyCmd}
    '';
}
