{ lib, rustPlatform, pkg-src }:
rustPlatform.buildRustPackage rec {
  pname = "manif-geom-rs";
  version = "0.0.0";
  src = pkg-src;
  useFetchCargoVendor = true;
  cargoHash = "sha256-9DtJHwyxkw1f7ANVG9xGv79j4ljwE99YQ3b952aqZJo=";
  meta = {
    description =
      "Rust implementation of [manif-geom-cpp](https://github.com/goromal/manif-geom-cpp) (*under construction*).";
    longDescription = ''
      [Repository](https://github.com/goromal/manif-geom-rs)

      ***TODO*** Once finished, these docs will contrast the API with `manif-geom-cpp`.
    '';
  };
}
