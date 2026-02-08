{ lib, rustPlatform, pkg-src }:
rustPlatform.buildRustPackage rec {
  pname = "xv-lidar-rs";
  version = "0.0.1";
  src = pkg-src;
  cargoHash =
    "sha256-w8OiSJpzTI++xDtCQpKwn2RnzqOXICh3SX4Gyiij30I="; # lib.fakeHash
  meta = {
    description = "Daemon for the Neato XV LiDAR (*not quite finished*).";
    longDescription = ''
      Written in Rust. [Repository](https://github.com/goromal/xv-lidar-rs)

      Currently the program will simply continuously print out 2D point cloud data to the console.
      I plan to instead have it stream gRPC 2D point cloud messages (defined in [aapis](https://github.com/goromal/aapis))
      to a [mscpp](../cpp/mscpp.md)-based daemon for real-time pose estimation over [SE(2)](../cpp/manif-geom-cpp.md).
    '';
    autoGenUsageCmd = "--help";
  };
}
