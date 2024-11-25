{ buildPythonPackage, pytestCheckHook, click, paramiko, scp, pkg-src }:
buildPythonPackage rec {
  pname = "rcdo";
  version = "0.0.0";
  src = pkg-src;
  propagatedBuildInputs = [ click paramiko scp ];
  doCheck = false;
  checkInputs = [ pytestCheckHook ];
  meta = {
    description = "Run commands on remote machines.";
    longDescription = ''
      [Repository](https://github.com/goromal/rcdo)
    '';
    autoGenUsageCmd = "--help";
  };
}
