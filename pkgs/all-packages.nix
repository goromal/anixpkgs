{ pkgs }:
rec {
    apkgs = {
        abcm2ps = pkgs.callPackage ./abcm2ps {
            stdenv = pkgs.clangStdenv;
        };
        abcmidi = pkgs.callPackage ./abcmidi {
            stdenv = pkgs.clangStdenv;
        };
    };
}
