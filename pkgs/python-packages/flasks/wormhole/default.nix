{
  buildPythonPackage,
  setuptools,
  pytestCheckHook,
  pkg-src,
}:
buildPythonPackage rec {
  pname = "wormhole";
  version = "0.0.0";
  pyproject = true;
  build-system = [ setuptools ];
  src = "${pkg-src}/wormhole";
  nativeCheckInputs = [ pytestCheckHook ];
  meta = {
    description = "Local-or-remote (ssh) file operations library shared by the flasks UIs.";
    longDescription = ''
      Stdlib-only helpers for listing, reading, writing, and deleting files
      either on the local filesystem or on a remote host over ssh (BatchMode,
      argv-array subprocess calls, shlex-quoted remote paths). Consuming
      services must have openssh on their PATH for remote operations.
    '';
  };
}
