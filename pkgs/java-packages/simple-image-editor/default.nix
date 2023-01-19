{ stdenv
, jdk
, jre
, ant
, makeWrapper
, pkg-src
}:
stdenv.mkDerivation {
    name = "simple-image-editor";
    version = "1.0.0";
    src = pkg-src;

    nativeBuildInputs = [ 
        jdk 
        ant
        makeWrapper
    ];

    buildPhase = "ant";

    installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/editor
    ls editor/editor
    cp editor/editor/*.class $out/share/editor
    makeWrapper ${jre}/bin/java $out/bin/simple-image-editor \
        --add-flags "-cp $out/share editor.ImageEditor"
    '';
}
