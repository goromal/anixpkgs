{
  lib,
  rustPlatform,
  pkg-src,
}:
rustPlatform.buildRustPackage rec {
  pname = "sunnyside";
  version = "0.2.0";
  src = pkg-src;
  cargoHash = "sha256-aAzaj78FkeY7Q74AaKBhmGAm1b0WAeylBEg3vdwiWYc=";
  meta = {
    description = "File scrambler.";
    longDescription = ''
      Written in Rust. [Repository](https://github.com/goromal/sunnyside)
    '';
    autoGenUsageCmd = "--help";
  };
}
