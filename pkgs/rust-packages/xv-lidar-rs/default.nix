{ lib
, rustPlatform
}:
rustPlatform.buildRustPackage rec {
    pname = "xv-lidar-rs";
    version = "0.0.1";
    src = builtins.fetchGit (import ./src.nix);
    cargoHash = "sha256-AO01Q2gyrwtjy2ng5TxkT3qh1C/WBIRjSR7USeObpwg="; # lib.fakeHash
}
