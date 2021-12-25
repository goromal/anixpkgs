# https://github.com/deezer/spleeter
{ buildPythonPackage
, fetchPypi
, ffmpeg
, libsndfile
}:
buildPythonPackage rec {
    pname = "spleeter";
    version = "2.3.0";
    nativeBuildInputs = [
        ffmpeg
        libsndfile
    ];
    src = fetchPypi {
        inherit pname version;
        sha256 = "1rphxf3vrn8wywjgr397f49s0s22m83lpwcq45lm0h2p45mdm458";
    };
    doCheck = false;
}