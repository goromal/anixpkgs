{ pname, version, description, longDescription ? "", autoGenUsageCmd ? "--help"
, script-file, is-exec ? true, test-dir ? null, pytestCheckHook
, buildPythonPackage, nativeBuildInputs ? [ ], propagatedBuildInputs ? [ ]
, checkPkgs ? [ ], subCmds ? [ ] }:
let
  testsCpyCmd = if test-dir != null then ''
    cp ${test-dir}/* tests/
  '' else
    "";
in buildPythonPackage rec {
  inherit pname;
  inherit version;
  src = ./pkgTemplate/.;
  inherit nativeBuildInputs;
  inherit propagatedBuildInputs;
  doCheck = (test-dir != null);
  checkInputs = [ pytestCheckHook ]
    ++ checkPkgs; # TODO fix below https://stackoverflow.com/questions/12461603/setting-up-setup-py-for-packaging-of-a-single-py-file-and-a-single-data-file-wi
  preConfigure = ''
    mkdir ${pname}
    ${if is-exec then "touch ${pname}/__init__.py" else ""}
    ${if is-exec then
      "cp ${script-file} ${pname}/cli.py"
    else
      "cp ${script-file} ${pname}/__init__.py"}
    sed -i 's|entry_points={},|${
      if is-exec then
        ''entry_points={"console_scripts":["${pname}=${pname}.cli:main"]},''
      else
        ""
    }|g' setup.py
    sed -i 's|_tmptitle|${pname}|g' __version__.py
    sed -i 's|_tmpdescription|${description}|g' __version__.py
    sed -i 's|_tmpversion|${version}|g' __version__.py
    ${testsCpyCmd}
  '';
  meta = { inherit description longDescription autoGenUsageCmd subCmds; };
}
