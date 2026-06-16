{
  stdenvNoCC,
  makeWrapper,
  python313,
  torch,
  torchsde,
  torchvision,
  torchaudio,
  numpy,
  einops,
  transformers,
  tokenizers,
  sentencepiece,
  safetensors,
  aiohttp,
  yarl,
  pyyaml,
  pillow,
  scipy,
  tqdm,
  psutil,
  alembic,
  sqlalchemy,
  requests,
  pydantic,
  pydantic-settings,
  kornia,
  spandrel,
  av,
  comfyui-frontend-package,
  comfyui-workflow-templates,
  comfyui-embedded-docs,
  ultralytics,
  opencv4,
  dill,
  scikit-image,
  piexif,
  matplotlib,
  gitpython,
  segment-anything,
  pkg-src,
}:
let
  pythonEnv = python313.withPackages (_ps: [
    torch
    torchsde
    torchvision
    torchaudio
    numpy
    einops
    transformers
    tokenizers
    sentencepiece
    safetensors
    aiohttp
    yarl
    pyyaml
    pillow
    scipy
    tqdm
    psutil
    alembic
    sqlalchemy
    requests
    pydantic
    pydantic-settings
    kornia
    spandrel
    av
    comfyui-frontend-package
    comfyui-workflow-templates
    comfyui-embedded-docs
    ultralytics
    opencv4
    dill
    scikit-image
    piexif
    matplotlib
    gitpython
    segment-anything
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "comfyui";
  version = "0.11.0";
  src = pkg-src;
  nativeBuildInputs = [ makeWrapper ];
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/comfyui $out/bin
    cp -r . $out/share/comfyui
    makeWrapper ${pythonEnv}/bin/python $out/bin/comfyui \
      --add-flags "$out/share/comfyui/main.py"
  '';
  meta = {
    description = "ComfyUI — node-based Stable Diffusion (SDXL) web UI.";
    longDescription = ''
      [Repository](https://github.com/comfyanonymous/ComfyUI)
    '';
  };
}
