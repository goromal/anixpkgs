{
  lib,
  rustPlatform,
  protobuf,
  bash,
  pkg-src,
  aapis-src,
}:
rustPlatform.buildRustPackage {
  pname = "bit-rs";
  version = "0.1.0";
  src = pkg-src;
  cargoHash = "sha256-cwicbxk5SAiJbIki2ihbk3JXRRv/LlW/XWkh7QAKuHY=";
  nativeBuildInputs = [ protobuf ];
  AAPIS_PROTO_DIR = "${aapis-src}/protos";
  BIT_TEST_SHELL = "${bash}/bin/bash";
  outputs = [
    "out"
    "internet"
    "avahi"
    "cozy_imgedit2"
  ];
  postInstall = ''
    mkdir -p $internet/bin $avahi/bin $cozy_imgedit2/bin
    mv $out/bin/bit-check-internet $internet/bin/
    mv $out/bin/bit-check-avahi $avahi/bin/
    mv $out/bin/bit-check-cozy-imgedit2 $cozy_imgedit2/bin/
  '';
  meta = {
    description = "Machine health and regression checks with bitd and the bitctl TUI.";
    longDescription = ''
      [Repository](https://github.com/goromal/bit-rs).
      Rust executable plugins run concurrently with deadlines and journal logging.
      Configure services.bitd.checks in NixOS; run bitctl to monitor health or
      bitctl run --wait to execute all installed regression checks.
    '';
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "bitctl";
  };
}
