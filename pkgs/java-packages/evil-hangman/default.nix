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

    meta = {
        description = "Interactive hangman game where you'll probably lose (because the computer is cheating).";
        longDescription = ''
        Written in Java. [Repository](https://github.com/goromal/evil-hangman)

        ```
        usage: evil-hangman <word-length> <num-guesses>
        ```
        '';
    };
}
