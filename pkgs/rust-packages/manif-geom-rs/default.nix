{ lib, rustPlatform, pkg-src }:
rustPlatform.buildRustPackage rec {
  pname = "manif-geom-rs";
  version = "0.0.0";
  src = pkg-src;
  cargoHash = "sha256-KbAGQ8V3hWx2i69d/JswkzaQSwizQUBzvPDaGGE6PBU=";
  meta = {
    description =
      "Rust implementation of [manif-geom-cpp](https://github.com/goromal/manif-geom-cpp) (*under construction*).";
    longDescription = ''
      [Repository](https://github.com/goromal/manif-geom-rs)

      ***TODO*** Once finished, these docs will contrast the API with `manif-geom-cpp`.
    '';
  };
}
