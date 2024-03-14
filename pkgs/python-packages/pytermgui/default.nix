{ buildPythonPackage, fetchPypi, pythonOlder, typing-extensions, wcwidth
, hatchling, hatch-fancy-pypi-readme }:
buildPythonPackage rec {
  pname = "pytermgui";
  version = "7.7.1";
  disabled = pythonOlder "3.6";
  propagatedBuildInputs =
    [ typing-extensions wcwidth hatchling hatch-fancy-pypi-readme ];
  format = "pyproject";
  src = fetchPypi {
    inherit pname version;
    sha256 = "030458be5c3cbeaab17fb9aa3d19e6232be4ce4a3f54418fe13bb97fdef446db";
  };
  meta = {
    description =
      "Python TUI framework with mouse support, modular widget system, customizable and rapid terminal markup language and more!";
    longDescription = ''
      [Third-party library](https://github.com/bczsalba/pytermgui) packaged in Nix as a dependency of [TODO](./todo.md).
    '';
  };
}
