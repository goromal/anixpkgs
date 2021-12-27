# https://github.com/deezer/spleeter
{ buildPythonPackage
, fetchPypi
, pythonAtLeast
, pythonOlder
, pandas
, tensorflow
, ffmpeg
, libsndfile
, ffmpeg-python
, norbert
, typer
, llvmlite
, numpy
, httpx
, librosa
}:
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
    nativeBuildInputs = [
        ffmpeg
        libsndfile
    ];
    disabled = pythonOlder "3.8" || pythonAtLeast "3.9";
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
        ${adjustDependency typer " = \"^0.3.2\"" ">=0.3.2,<0.4.0" " (>=0.3.2,<0.4.0)"}
        ${adjustDependency llvmlite " = \"^0.36.0\"" ">=0.36.0,<0.37.0" " (>=0.36.0,<0.37.0)"}
        ${adjustDependency numpy " = \"<1.20.0,>=1.16.0\"" ">=1.16.0,<1.20.0" " (>=1.16.0,<1.20.0)"}
        ${adjustDependency librosa " = \"0.8.0\"" "==0.8.0" " (==0.8.0)"}
        substituteInPlace spleeter/model/functions/unet.py --replace 'tensorflow.compat.v1.keras' 'tensorflow.keras'
    '';
    src = fetchPypi {
        inherit pname version;
        sha256 = "b8b07a021c9b600c1e8aec73e5ff3fd4cce01b493f0661e77e2195f0c105bc59";
    };
    doCheck = false;
}
