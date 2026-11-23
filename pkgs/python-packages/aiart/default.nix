{
  lib,
  python313Packages,
  pkg-src,
}:
python313Packages.buildPythonApplication {
  pname = "aiart";
  version = "0.1.0";
  pyproject = true;

  src = pkg-src;

  build-system = [ python313Packages.setuptools ];
  dependencies = with python313Packages; [
    pillow
    requests
    (textual.overridePythonAttrs { doCheck = false; })
  ];
  nativeCheckInputs = [ python313Packages.pytestCheckHook ];

  pythonImportsCheck = [ "aiart" ];

  meta = {
    description = "Agent-driven local 2D and 3D art workflows";
    longDescription = ''
      A TUI that opens agent sessions per art project for 2D and 3D art.
    '';
    autoGenUsageCmd = "--help";
    platforms = lib.platforms.linux;
    mainProgram = "aiart";
  };
}
