{ stdenv }:
stdenv.mkDerivation {
    pname = "abcm2ps";
    version = "1.0.0";
    src = builtins.fetchGit (import ./src.nix);
    nativeBuildInputs = [];
    buildInputs = [];
    configurePhase = ''
        ./configure
    '';
    installPhase = ''
        mkdir -p $out/bin
        cp abcm2ps $out/bin
    '';
}
