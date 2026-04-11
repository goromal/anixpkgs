{
  lib,
  rustPlatform,
  pkg-src,
}:
rustPlatform.buildRustPackage rec {
  pname = "rtk";
  version = "0.1.0";
  src = pkg-src;
  cargoHash = lib.fakeHash;
  meta = {
    description = "CLI proxy that reduces LLM token consumption by filtering and compressing command outputs.";
    longDescription = ''
      Written in Rust. [Repository](https://github.com/rtk-ai/rtk)
    '';
    autoGenUsageCmd = "--help";
  };
}
