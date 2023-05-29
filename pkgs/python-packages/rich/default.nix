{ lib
, buildPythonPackage
, fetchFromGitHub
, pythonOlder
, markdown-it-py
, poetry-core
, pygments
, typing-extensions
, ipywidgets
, pytestCheckHook

# for passthru.tests
, enrich
, httpie
, rich-rst
, textual
}:

buildPythonPackage rec {
  pname = "rich";
  version = "13.3.3";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "Textualize";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-eWX8lo9F/CxTlTtoSnkl4XeJPI5jSXFj22YptnVVWCM=";
  };

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = [
    ipywidgets
    markdown-it-py
    pygments
  ] ++ lib.optionals (pythonOlder "3.9") [
    typing-extensions
  ];

  nativeCheckInputs = [
    pytestCheckHook
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace 'markdown-it-py = "^2.2.0"' 'markdown-it-py = "*"'
  '';

  pythonImportsCheck = [
    "rich"
  ];

  passthru.tests = {
    inherit enrich httpie rich-rst textual;
  };

  meta = with lib; {
    description = "Render rich text, tables, progress bars, syntax highlighting, markdown and more to the terminal";
    homepage = "https://github.com/Textualize/rich";
    changelog = "https://github.com/Textualize/rich/blob/v${version}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ ris joelkoen ];
  };
}
