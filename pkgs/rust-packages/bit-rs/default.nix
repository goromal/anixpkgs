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
    "cozy_imggen_quantized"
    "nvidia_power"
    "ardupilot"
    "ros2_topics"
    "user_units"
    "systemd_units"
    "ssh_known_hosts"
  ];
  postInstall = ''
    mkdir -p $internet/bin $avahi/bin $cozy_imgedit2/bin $cozy_imggen_quantized/bin $nvidia_power/bin \
      $ardupilot/bin $ros2_topics/bin $user_units/bin $systemd_units/bin \
      $ssh_known_hosts/bin
    mv $out/bin/bit-check-internet $internet/bin/
    mv $out/bin/bit-check-avahi $avahi/bin/
    mv $out/bin/bit-check-cozy-imgedit2 $cozy_imgedit2/bin/
    mv $out/bin/bit-check-cozy-imggen-quantized $cozy_imggen_quantized/bin/
    mv $out/bin/bit-check-nvidia-power $nvidia_power/bin/
    mv $out/bin/bit-check-ardupilot $ardupilot/bin/
    mv $out/bin/bit-check-ros2-topics $ros2_topics/bin/
    mv $out/bin/bit-check-user-units $user_units/bin/
    mv $out/bin/bit-check-systemd-units $systemd_units/bin/
    mv $out/bin/bit-check-ssh-known-hosts $ssh_known_hosts/bin/
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
