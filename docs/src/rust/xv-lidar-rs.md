# xv-lidar-rs

Daemon for the Neato XV LiDAR (*not quite finished*).

Written in Rust. [Repository](https://github.com/goromal/xv-lidar-rs)

## Usage

```bash
Usage: xv-lidar-rs [OPTIONS]

Options:
-d, --device <DEVICE>  Device name [default: /dev/ttyACM0]
-h, --help             Print help information
-V, --version          Print version information
```

## Roadmap

Currently the program will simply continuously print out 2D point cloud data to the console.
I plan to instead have it stream gRPC 2D point cloud messages (defined in [aapis](https://github.com/goromal/aapis))
to a [mscpp](../cpp/mscpp.md)-based daemon for real-time pose estimation over [SE(2)](../cpp/manif-geom-cpp.md).


