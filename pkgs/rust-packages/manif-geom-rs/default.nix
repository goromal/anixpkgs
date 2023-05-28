{ lib
, rustPlatform
, pkg-src
}:
rustPlatform.buildRustPackage rec {
    pname = "manif-geom-rs";
    version = "0.0.0";
    src = pkg-src;
    cargoHash = "sha256-ceayumOzXbEFi2j42BIXXo9L3r/VFgUyfNUuk3vhYu8=";
}
