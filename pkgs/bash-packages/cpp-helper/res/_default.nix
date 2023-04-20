let pkgs = import <anixpkgs> {};
in with pkgs; clangStdenv.mkDerivation {
  name = "REPLACEME";
    version = "0.0.0";
    src = lib.cleanSource ./.;
    nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        # ADD depts
    ];
    preConfigure = ''
    cmakeFlags="$cmakeFlags --no-warn-unused-cli"
    '';
}
