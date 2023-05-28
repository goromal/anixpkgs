{ lib
, buildPythonPackage
, fetchFromGitHub
, poetry-core
, rich
, typing-extensions
, aiohttp
, linkify-it-py
, importlib-metadata
, mdit-py-plugins
, msgpack
, jinja2
, syrupy
, pytestCheckHook
, pythonOlder
}:

buildPythonPackage rec {
  pname = "textual";
  version = "0.20.1";
  format = "pyproject";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "Textualize";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-uOTCq+wpgz8QbcMQvy4/hptwcH4/MINYUpfwhVpPOq4=";
  };

  nativeBuildInputs = [
    poetry-core
  ];

  propagatedBuildInputs = [
    rich
    aiohttp
    mdit-py-plugins
    linkify-it-py
    typing-extensions
    importlib-metadata
    msgpack
    jinja2
    syrupy
  ];

  checkInputs = [
    pytestCheckHook
  ];

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace 'typing-extensions = "^4.4.0"' 'typing-extensions = "*"' \
      --replace 'markdown-it-py = {extras = ["plugins", "linkify"], version = "^2.1.0"}' 'markdown-it-py = "*"'
  '';

  pythonImportsCheck = [
    "textual"
  ];

  doCheck = false;
}
