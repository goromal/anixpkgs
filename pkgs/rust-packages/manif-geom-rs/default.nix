{
  lib,
  rustPlatform,
  pkg-src,
}:
rustPlatform.buildRustPackage rec {
  pname = "manif-geom-rs";
  version = "0.0.0";
  src = pkg-src;
  cargoHash = "sha256-Y7pS5WeFLRdj9jrWiA/kbHdzkdZL+eEZ9Ft0Wh2XNr0=";
  meta = {
    description = "Rust implementation of [manif-geom-cpp](https://github.com/goromal/manif-geom-cpp) (*under construction*).";
    longDescription = ''
      [Repository](https://github.com/goromal/manif-geom-rs)

      ***TODO*** Once finished, these docs will contrast the API with `manif-geom-cpp`.

      - [x] SO2
      - [ ] SO3
      - [ ] SE2
      - [ ] SE3
    '';
  };
}
