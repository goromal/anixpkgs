{ stdenv, jdk, jre, ant, makeWrapper, pkg-src }:
stdenv.mkDerivation {
  name = "simple-image-editor";
  version = "1.0.0";
  src = pkg-src;

  nativeBuildInputs = [ jdk ant makeWrapper ];

  buildPhase = "ant";

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/editor
    ls editor/editor
    cp editor/editor/*.class $out/share/editor
    makeWrapper ${jre}/bin/java $out/bin/simple-image-editor \
        --add-flags "-cp $out/share editor.ImageEditor"
  '';

  meta = {
    description =
      "Perform some simple image transformations from the command line.";
    longDescription = ''
      Written in Java. [Repository](https://github.com/goromal/simple-image-editor)

      Input and output images must be in the [PPM](https://netpbm.sourceforge.net/doc/ppm.html) image format.

      ```
      usage: simple-image-editor <input.ppm> <output.ppm> [grayscale|invert|emboss|motionblur motion-blur-length]
      ```
    '';
  };
}
