{ lib, rustPlatform, pkg-src }:
rustPlatform.buildRustPackage rec {
  pname = "sunnyside";
  version = "0.1.0";
  src = pkg-src;
  cargoHash = "sha256-iKjsrQ/u9SwQZNlSMPjJOxLRSbBuE21Ae0jnJ60fKoE=";
  meta = {
    description = "File scrambler.";
    longDescription = ''
      Written in Rust. [Repository](https://github.com/goromal/sunnyside)
    '';
    autoGenUsageCmd = "--help";
  };
}
