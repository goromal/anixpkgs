{
  stdenv,
  jdk,
  jre,
  ant,
  makeWrapper,
  pkg-src,
}:
stdenv.mkDerivation {
  name = "spelling-corrector";
  version = "1.0.0";
  src = pkg-src;

  nativeBuildInputs = [
    jdk
    ant
    makeWrapper
  ];

  patches = [ ./patches/args.patch ];

  buildPhase = "ant";

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/spell
    cp dictionary.txt $out
    cp spell/spell/*.class $out/share/spell
    makeWrapper ${jre}/bin/java $out/bin/spelling-corrector \
        --add-flags "-cp $out/share spell.Main $out/dictionary.txt"
  '';

  meta = {
    description = "Offer up spelling corrections for provided mispelled words.";
    longDescription = ''
      Written in Java. [Repository](https://github.com/goromal/spelling-corrector)

      The repository contains the text-file dictionary from which all word suggestions derive.

      ```
      usage: spelling-corrector <word>
      ```
    '';
  };
}
