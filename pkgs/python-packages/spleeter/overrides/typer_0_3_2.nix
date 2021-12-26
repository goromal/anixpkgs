{ lib
, stdenv
, buildPythonPackage
, fetchPypi
, click
, pytestCheckHook
, shellingham
, pytest-xdist
, pytest-sugar
, coverage
, mypy
, black
, isort
, pythonOlder
}:

buildPythonPackage rec {
  pname = "typer";
  version = "0.3.2";

  disabled = pythonOlder "3.6";

  src = fetchPypi {
    inherit pname version;
    sha256 = "5455d750122cff96745b0dec87368f56d023725a7ebc9d2e54dd23dc86816303";
  };

  propagatedBuildInputs = [
    click
  ];

  checkInputs = [
    pytestCheckHook
    pytest-xdist
    pytest-sugar
    shellingham
    coverage
    mypy
    black
    isort
  ];

  preCheck = ''
    export HOME=$(mktemp -d);
  '';
  disabledTests = lib.optionals stdenv.isDarwin [
    # likely related to https://github.com/sarugaku/shellingham/issues/35
    "test_show_completion"
    "test_install_completion"
  ];

  pythonImportsCheck = [ "typer" ];

  meta = with lib; {
    description = "Python library for building CLI applications";
    homepage = "https://typer.tiangolo.com/";
    license = licenses.mit;
    maintainers = with maintainers; [ winpat ];
  };
}
