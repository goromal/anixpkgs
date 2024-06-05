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

      ## Usage

      ```bash
      Make some scrambled eggs

      Usage: sunnyside --target <TARGET> --shift <SHIFT> --key <KEY>

      Options:
        -t, --target <TARGET>  File target
        -s, --shift <SHIFT>    Shift amount
        -k, --key <KEY>        Scramble key
        -h, --help             Print help
        -V, --version          Print version
      ```
    '';
  };
}
