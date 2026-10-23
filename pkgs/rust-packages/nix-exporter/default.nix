{
  lib,
  rustPlatform,
  pkg-src,
}:
rustPlatform.buildRustPackage rec {
  pname = "nix-exporter";
  version = "0.1.0";
  src = pkg-src;
  cargoHash = "sha256-H90azpEuuXO6187IENmPLHHuw16rbftjUnQmZF38TaE=";
  # The test suite exercises a live Nix store and daemon, unavailable in the sandbox.
  doCheck = false;
  meta = {
    description = "Prometheus exporter for the Nix store and daemon.";
    longDescription = ''
      Written in Rust. [Repository](https://github.com/burk3/nix-exporter)
    '';
    mainProgram = "nix-exporter";
    license = lib.licenses.mit;
    autoGenUsageCmd = "--help";
  };
}
