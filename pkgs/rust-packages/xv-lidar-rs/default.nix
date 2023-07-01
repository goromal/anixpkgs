{ lib
, rustPlatform
, pkg-src
}:
rustPlatform.buildRustPackage rec {
    pname = "xv-lidar-rs";
    version = "0.0.1";
    src = pkg-src;
    cargoHash = "sha256-AO01Q2gyrwtjy2ng5TxkT3qh1C/WBIRjSR7USeObpwg="; # lib.fakeHash
    meta = {
        description = "Daemon for the Neato XV LiDAR (*not quite finished*).";
        longDescription = ''
        Written in Rust. [Repository](https://github.com/goromal/xv-lidar-rs)

        ```bash
        Usage: xv-lidar-rs [OPTIONS]

        Options:
        -d, --device <DEVICE>  Device name [default: /dev/ttyACM0]
        -h, --help             Print help information
        -V, --version          Print version information
        ```
        '';
    };
}
