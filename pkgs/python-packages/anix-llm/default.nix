{
  bash,
  lib,
  makeWrapper,
  python313Packages,
  systemd,
  tmux,
}:
python313Packages.buildPythonApplication {
  pname = "anix-llm";
  version = "1.0.0";
  pyproject = true;

  src = lib.cleanSource ./.;

  build-system = [ python313Packages.setuptools ];
  nativeBuildInputs = [ makeWrapper ];
  nativeCheckInputs = [ python313Packages.pytestCheckHook ];

  postInstall = ''
    wrapProgram $out/bin/anix-llm \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          systemd
          tmux
        ]
      }
  '';

  pythonImportsCheck = [ "anix_llm" ];

  meta = {
    description = "Private local LLM workflows";
    longDescription = ''
      Unified commands for local text generation, bounded directory context,
      guarded file writing, memory-only chat, model management, and a tmux
      workspace backed by one Ollama service.
    '';
    autoGenUsageCmd = "--help";
    platforms = lib.platforms.linux;
    mainProgram = "anix-llm";
  };
}
