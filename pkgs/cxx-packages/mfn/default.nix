{ clangStdenv
, makeWrapper
, cmake
, boost
, opencv
, model-proto
, model-weights
, pkg-src
}:
clangStdenv.mkDerivation {
    name = "mfn";
    version = "1.0.0";
    src = pkg-src;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        makeWrapper
        boost
        opencv
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
    postInstall = ''
    wrapProgram $out/bin/mfn \
      --add-flags "--model-proto=${model-proto} --model-weights=${model-weights}"
    '';
}
