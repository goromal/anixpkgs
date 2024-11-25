{ lib, rustPlatform, pkg-src }:
rustPlatform.buildRustPackage rec {
  pname = "sunnyside";
  version = "0.1.0";
  src = pkg-src;
  cargoHash = "sha256-Aq2PPn1n4/AgMY51TyB460nXcd4SjFx00QqCSwq1eiU=";
  meta = {
    description = "File scrambler.";
    longDescription = ''
      Written in Rust. [Repository](https://github.com/goromal/sunnyside)
    '';
    autoGenUsageCmd = "--help";
  };
}
