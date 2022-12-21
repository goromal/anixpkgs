{ stdenv
, jdk
, jre
, ant
, makeWrapper
, pkg-src
}:
stdenv.mkDerivation {
    name = "evil-hangman";
    version = "1.0.0";
    src = pkg-src;

    nativeBuildInputs = [ 
        jdk 
        ant
        makeWrapper
    ];

    patches = [
        ./patches/args.patch
    ];

    buildPhase = "ant";

    installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/hangman
    cp dictionary.txt $out
    cp hangman/hangman/*.class $out/share/hangman
    makeWrapper ${jre}/bin/java $out/bin/evil-hangman \
        --add-flags "-cp $out/share hangman.EvilHangman $out/dictionary.txt"
    '';
}
