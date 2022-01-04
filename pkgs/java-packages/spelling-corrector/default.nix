{ stdenv
, jdk
, jre_minimal
, ant
, makeWrapper
}:
let
    min_jre = jre_minimal.override {
        inherit jdk;
        modules = [
            "java.base"
            "java.logging"
        ];
    };
in stdenv.mkDerivation {
    name = "evil-hangman";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);

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
    mkdir -p $out/share/spell
    cp dictionary.txt $out
    cp spell/spell/*.class $out/share/spell
    makeWrapper ${min_jre}/bin/java $out/bin/spelling-corrector \
        --add-flags "-cp $out/share spell.Main $out/dictionary.txt"
    '';
}
