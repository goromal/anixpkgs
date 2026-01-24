{ buildPythonPackage, pytestCheckHook, click, easy-google-auth, pkg-src }:
buildPythonPackage rec {
  pname = "task-tools";
  version = "0.0.1";
  src = pkg-src;
  propagatedBuildInputs = [ click easy-google-auth ];
  doCheck = true;
  checkInputs = [ pytestCheckHook ];
  meta = {
    description = "CLI tools for managing Google Tasks.";
    longDescription = ''
      [Repository](https://github.com/goromal/task-tools)
    '';
    autoGenUsageCmd = "--help";
    subCmds = [ "list" "delete" "put" "grader" ];
  };
}
