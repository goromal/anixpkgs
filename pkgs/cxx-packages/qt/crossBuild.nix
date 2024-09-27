{ pkgs, pkgSrc, dependencies ? [] }:
let
    nixcrpkgs = import (builtins.fetchGit {
        url = "git@github.com:pololu/nixcrpkgs.git";
        rev = "b18af2550b0ff1a55751c4c64cd802261b1d6b59";
        ref = "master";
    }) { nixpkgs = pkgs; };
    mkPayload = env: env.make_derivation {
        builder = pkgs.writeShellScript "builder.sh" ''
            source $setup
            cmake-cross $src -DBUILD_SHARED_LIBS=false -DCMAKE_INSTALL_PREFIX=$out
            make
            make install
            $host-strip $out/bin/*
            if [ $os = "linux" ]; then
                cp $dejavu/ttf/DejaVuSans.ttf $out/bin/
            fi
        '';
        src = pkgSrc;
        cross_inputs = [ env.qt ];
        native_inputs = dependencies;
        dejavu = (if env.os == "linux" then env.dejavu-fonts else null);
    };
in rec {
    linux-x86 = mkPayload nixcrpkgs.linux-x86;
    win32 = mkPayload nixcrpkgs.win32;
}
