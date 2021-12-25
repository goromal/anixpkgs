{ stdenv }:
stdenv.mkDerivation {
    pname = "abcmidi";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);
    nativeBuildInputs = [];
    buildInputs = [];
    configurePhase = ''
        ./configure
    '';
    installPhase = ''
        mkdir -p $out/bin
        cp abc2abc $out/bin
        cp abc2midi $out/bin
        cp abcmatch $out/bin
        cp midi2abc $out/bin
    '';
}
