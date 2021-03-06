{ stdenv
, jdk
, jre
, ant
, makeWrapper
}:
stdenv.mkDerivation {
    name = "spelling-corrector";
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
    makeWrapper ${jre}/bin/java $out/bin/spelling-corrector \
        --add-flags "-cp $out/share spell.Main $out/dictionary.txt"
    '';
}
