{ buildPythonPackage, setuptools, fetchPypi, pythonOlder, scipy }:
buildPythonPackage rec {
  pname = "norbert";
  version = "0.2.1";
  pyproject = true;
  build-system = [ setuptools ];
  disabled = pythonOlder "3.6";
  propagatedBuildInputs = [ scipy ];
  src = fetchPypi {
    inherit pname version;
    sha256 = "bd4cbc2527f0550b81bf4265c1a64b352cab7f71e4e3c823d30b71a7368de74e";
  };
  meta = {
    description = "Painless Wiener filters for audio separation.";
    longDescription = ''
      [Third-party library](https://github.com/sigsep/norbert) packaged in Nix as a dependency of [spleeter](./spleeter.md).
    '';
  };
}
