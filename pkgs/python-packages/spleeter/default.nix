# https://github.com/deezer/spleeter
{ buildPythonPackage
, fetchPypi
, pythonOlder
, pandas
, tensorflow
, ffmpeg
, libsndfile
, ffmpeg-python
, norbert
, typer
, llvm-lite
, numpy
}:
let
    makeAdjustment = pn: 
in buildPythonPackage rec {
    pname = "spleeter";
    version = "2.3.0";
    nativeBuildInputs = [
        ffmpeg
        libsndfile
    ];
    # TODO only 3.8
    disabled = pythonOlder "3.8";
    propagatedBuildInputs = [
        numpy
        pandas
        typer
        tensorflow
        llvm-lite
        ffmpeg-python
        norbert
    ];
    postPatch = ''
        substituteInPlace pyproject.toml --replace 'tensorflow = "2.5.0"' 'tensorflow = "2.7.0"'
        substituteInPlace setup.py --replace 'tensorflow==2.5.0' 'tensorflow==2.7.0'
        substituteInPlace PKG-INFO --replace 'tensorflow (==2.5.0)' 'tensorflow (==2.7.0)'
    '';
    src = fetchPypi {
        inherit pname version;
        sha256 = "b8b07a021c9b600c1e8aec73e5ff3fd4cce01b493f0661e77e2195f0c105bc59";
    };
    doCheck = false;
}
