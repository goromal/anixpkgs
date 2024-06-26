# https://github.com/deezer/spleeter
{ buildPythonPackage, fetchPypi, pythonAtLeast, pythonOlder, pandas, tensorflow
, ffmpeg, libsndfile, ffmpeg-python, norbert, typer, llvmlite, numpy, httpx
, librosa }:
let
  adjustDependency = ppackage: ppSpec: sSpec: pSpec: ''
    substituteInPlace pyproject.toml --replace '${ppackage.pname}${ppSpec}' '${ppackage.pname} = "${ppackage.version}"'
    substituteInPlace setup.py --replace '${ppackage.pname}${sSpec}' '${ppackage.pname}==${ppackage.version}'
    substituteInPlace PKG-INFO --replace '${ppackage.pname}${pSpec}' '${ppackage.pname} (==${ppackage.version})'
  '';
  tfVers = tensorflow.version;
in buildPythonPackage rec {
  pname = "spleeter";
  version = "2.3.0";
  nativeBuildInputs = [ ffmpeg libsndfile ];
  disabled = pythonOlder "3.8" || pythonAtLeast "3.9";
  broken = true;
  propagatedBuildInputs = [
    numpy
    pandas
    typer
    tensorflow
    llvmlite
    ffmpeg-python
    norbert
    httpx
    librosa
  ];
  postPatch = ''
    ${adjustDependency tensorflow " = \"2.5.0\"" "==2.5.0" " (==2.5.0)"}
    ${adjustDependency typer " = \"^0.3.2\"" ">=0.3.2,<0.4.0"
    " (>=0.3.2,<0.4.0)"}
    ${adjustDependency llvmlite " = \"^0.36.0\"" ">=0.36.0,<0.37.0"
    " (>=0.36.0,<0.37.0)"}
    ${adjustDependency numpy " = \"<1.20.0,>=1.16.0\"" ">=1.16.0,<1.20.0"
    " (>=1.16.0,<1.20.0)"}
    ${adjustDependency librosa " = \"0.8.0\"" "==0.8.0" " (==0.8.0)"}
    substituteInPlace pyproject.toml --replace 'version = \"^0.19.0\"' 'version = "${httpx.version}"'
    substituteInPlace setup.py --replace 'httpx[http2]>=0.19.0,<0.20.0' 'httpx[http2]==${httpx.version}'
    substituteInPlace PKG-INFO --replace 'httpx[http2] (>=0.19.0,<0.20.0)' 'httpx[http2] (==${httpx.version})'
    substituteInPlace spleeter/model/functions/unet.py --replace 'tensorflow.compat.v1.keras' 'tensorflow.keras'
  '';
  src = fetchPypi {
    inherit pname version;
    sha256 = "b8b07a021c9b600c1e8aec73e5ff3fd4cce01b493f0661e77e2195f0c105bc59";
  };
  doCheck = false;
  meta = {
    description =
      "Deezer source separation library including pretrained models.";
    longDescription = ''
      [Third-party library](https://github.com/deezer/spleeter) packaged in Nix. It allows you to separate vocals from background instrumentation in audio files.

      ***Note:*** As of this writing, this package is broken on master. There is a pinned version that builds on the [spleeter-legacy tag](https://github.com/goromal/anixpkgs/releases/tag/spleeter-legacy).
    '';
  };
}
# mkdir -p ~/spleeter/pretrained_models/2stems
# wget -qO- https://github.com/deezer/spleeter/releases/download/v1.4.0/2stems.tar.gz | tar xvz -C ~/spleeter/pretrained_models/2stems
