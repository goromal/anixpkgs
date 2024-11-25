{ lib, rustPlatform, pkg-src }:
rustPlatform.buildRustPackage rec {
  pname = "manif-geom-rs";
  version = "0.0.0";
  src = pkg-src;
  cargoHash = "sha256-ceayumOzXbEFi2j42BIXXo9L3r/VFgUyfNUuk3vhYu8=";
  meta = {
    description =
      "Rust implementation of [manif-geom-cpp](https://github.com/goromal/manif-geom-cpp) (*under construction*).";
    longDescription = ''
      [Repository](https://github.com/goromal/manif-geom-rs)

      ***TODO*** Once finished, these docs will contrast the API with `manif-geom-cpp`.
    '';
  };
}
