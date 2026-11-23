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
      A TUI that opens Claude or Codex sessions per art project, plus the
      commands those agents drive: 2D generation and editing through cozy,
      image-to-mesh through ComfyUI, and a live bridge into the user's
      Blender session. Model choice is configuration, not agent knowledge.
    '';
    autoGenUsageCmd = "--help";
    platforms = lib.platforms.linux;
    mainProgram = "aiart";
  };
}
