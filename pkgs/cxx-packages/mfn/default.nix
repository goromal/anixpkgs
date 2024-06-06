{ clangStdenv, makeWrapper, cmake, boost, opencv, model-proto, model-weights
, pkg-src }:
clangStdenv.mkDerivation {
  name = "mfn";
  version = "1.0.0";
  src = pkg-src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ makeWrapper boost opencv ];
  preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
  '';
  postInstall = ''
    wrapProgram $out/bin/mfn \
      --add-flags "--model-proto=${model-proto} --model-weights=${model-weights}"
  '';
  meta = {
    description =
      "Simple CLI tool meant to analyze an image of a single person and print whether the person appears to be a male (m), female (f), or neither (n).";
    longDescription = ''
      [Repository](https://github.com/goromal/mfn)

      Uses vanilla OpenCV tools. Depending on the model, it can be pretty trigger-happy classifying genders even on inanimate objects, so for best results only use images of one person. Neural network model description and weights **not included**.
    '';
    autoGenUsageCmd = "--help";
  };
}
