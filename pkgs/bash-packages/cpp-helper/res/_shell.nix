let pkgs = import <anixpkgs> {};
in with pkgs; mkShell {
  nativeBuildInputs = [
        cmake
    ];
    buildInputs = [
        # ADD deps
    ];
}
