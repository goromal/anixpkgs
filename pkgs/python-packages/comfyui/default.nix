{
  stdenvNoCC,
  makeWrapper,
  python313,
  torch,
  torchsde,
  torchvision,
  torchaudio,
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
  kornia,
  spandrel,
  soundfile,
  av,
  pkg-src,
}:
let
  pythonEnv = python313.withPackages (_ps: [
    torch
    torchsde
    torchvision
    torchaudio
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
    kornia
    spandrel
    soundfile
    av
  ]);
in
stdenvNoCC.mkDerivation {
  pname = "comfyui";
  version = "0.0.0";
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
