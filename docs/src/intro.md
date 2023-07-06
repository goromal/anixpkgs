# anixpkgs

![example workflow](https://github.com/goromal/anixpkgs/actions/workflows/test.yml/badge.svg)

![](https://raw.githubusercontent.com/goromal/anixdata/master/data/img/anixpkgs.png "anixpkgs")

**[Repository](https://github.com/goromal/anixpkgs)**

This repository of personally maintained Nix derivations, overlays, and machine closures is essentially the centralized mechanism by which I maintain all of the software I write and use for both personal projects and recreation. In other words, I employ [Nix](https://nixos.org) as both a package manager for my software as well as an operating system for all of my computers, Raspberry Pi’s, etc.

Some of the main reasons why I prefer Nix as a package manager:

- I highly value code that is not only compelling in its application but that is also **maintainable**. Code that is subject to compiler/interpreter and external dependency changes over time must be designed with the future in mind. Nix provides me an almost trivial mechanism to incrementally update (and roll back) external dependencies, compilers, or anything else pertaining to a software ecosystem that you can think of.
- When I write a cool piece of software on one machine, I want to be able to “deploy” that software across all my machines with minimal effort and without having to worry about broken or missing dependencies. With its hermetic build system, I have the peace of mind that the code that I package in Nix will be **transferable** to essentially any other machine that uses Nix.

Some of the main reasons why I prefer NixOS as an operating system for all of my computers:

- The same things I value in packaging software, I also value in “packaging an operating system.” NixOS allows me to have **total control** over every single package in my OS, allowing me to customize every aspect and make changes with the peace of mind that I can always roll back breaking changes.
- There is something very satisfying and empowering to me about being able to **declaratively define the OS closures for all of my machines in just several text files.** The overlay-focused design of NixOS modules makes it so that I can design the OS’s of my machines hierarchically, defining packages that are shared between *all* of my computers as well as packages that are specific to certain computers only. Moreover, when I buy a replacement computer it takes a minimal amount of steps to turn that new computer into an *all-intents-and-purposes clone* of my old one, which is a capability I value very highly for a lot of reasons.

These docs provide an overview of how I manage the OS’s of my [machines](./machines.md) as well as the [C++](./cpp/cpp.md), [Python](./python/python.md), and [miscellaneous](./misc/misc.md) software that I personally maintain, all within the [anixpkgs](https://github.com/goromal/anixpkgs) repo.

## Installation and Usage Patterns

The packages defined in this repo are accessible to anyone who uses [Nix](https://nixos.org), which can be [installed](https://nixos.org/download.html) in two forms:

- **“Standalone” Nix:** This will just install the package manager and is the easiest option if you just want access to the packages in this repo. This option could be augmented with a tool called [home-manager](https://nix-community.github.io/home-manager/) to at least be able to use *some* of the closure components alongside your normal OS as well.
- TODO

TODO

To use, clone this repo and add to `~/.bashrc`:

```bash
export NIX_PATH=nixpkgs=/your/path/to/anixpkgs
```

and in your Nix derivations:

```nix
let pkgs = import <nixpkgs> {};
```
An example Nix shell for trying out Python packages:

```nix
{ pkgs ? import <nixpkgs> {} }:
let
  python-with-my-packages = pkgs.python39.withPackages (p: with p; [
    numpy
    matplotlib
    geometry
    pyceres
  ]);
in
python-with-my-packages.env
```

or:

```nix
let
  pkgs = import <anixpkgs> {};
in pkgs.mkShell {
  buildInputs = [
    pkgs.python39
    pkgs.python39.pkgs.numpy
    pkgs.python39.pkgs.geometry
    pkgs.python39.pkgs.find_rotational_conventions
  ];
  shellHook = ''
    # Tells pip to put packages into $PIP_PREFIX instead of the usual locations.
    # See https://pip.pypa.io/en/stable/user_guide/#environment-variables.
    export PIP_PREFIX=$(pwd)/_build/pip_packages
    export PYTHONPATH="$PIP_PREFIX/${pkgs.python39.sitePackages}:$PYTHONPATH"
    export PATH="$PIP_PREFIX/bin:$PATH"
    unset SOURCE_DATE_EPOCH
  '';
}
```

## Build a Raspberry Pi NixOS SD Installer Image

```bash
nixos-generate -f sd-aarch64-installer --system aarch64-linux -c /path/to/rpi/config.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
nix-shell -p zstd --run "unzstd -d /nix/store/path/to/image.img.zst"
```

```bash
sudo dd if=/path/to/image.img of=/dev/sdX bs=4096 conv=fsync status=progress
```

On the Pi, copy over SSH keys (including to `/root/.ssh/`!) and then set up the Nix channel:

```bash
sudo nix-channel --add https://nixos.org/channels/nixos-[NIXOS-VERSION] nixos
sudo nix-channel --update
```

## Installation Instructions on a New Machine

*Sources*

- https://nixos.wiki/wiki/NixOS_Installation_Guide
- https://alexherbo2.github.io/wiki/nixos/install-guide/

1. Download a [NixOS ISO](https://nixos.org/nixos/download.html) image.
2. Plug in a USB stick large enough to accommodate the image.
3. Find the right device with `lsblk` or `fdisk -l`. Replace `/dev/sdX` with the proper device (do not use `/dev/sdX1` or partitions of the disk; use the whole disk `/dev/sdX`).
4. Burn ISO to USB stick with 
```bash
cp nixos-xxx.iso /dev/sdX
# OR
dd if=nixos.iso of=/dev/sdX bs=4M status=progress conv=fdatasync
```
5. On the new machine, one-time boot UEFI into the USB stick on the computer (will need to disable Secure Boot from BIOS first)
6. Wipe the file system: 
```bash
wipefs [--all -a] /dev/sda
```
7. `gparted`
   1. Create a GUID table: *Device* > *Create Partition Table* > *GPT*
      1. Select `/dev/sda`
      2. *Entire disk*
   2. Create the boot partition: *Partition* > *New*
      1. Free space preceding (MiB): 1
      2. New size (MiB): 512
      3. Free space following (MiB): Rest
      4. Align to: MiB
      5. Create as: Primary Partition
      6. Partition name: EFI
      7. File system: `fat32`
      8. Label: EFI
   3. Add the `boot` flag
      1. Right-click on `/dev/sda1` to manage flags
      2. Add the `boot` flag and enable `esp` (should be automatic with GPT)
   4. Create the root partition: *Partition* > *New*
      1. Free space preceding (MiB): 0
      2. New size (MiB): Rest
      3. Free space following (MiB): 0
      4. Align to: MiB
      5. Create as: Primary Partition
      6. Partition name: NixOS
      7. File system: `ext4`
      8. Label: NixOS
   5. Apply modifications
8. Mount root and boot partitions:
```bash
mkdir /mnt/nixos
mount /dev/disk/by-label/NixOS /mnt/nixos
mkdir /mnt/nixos/boot
mount /dev/disk/by-label/EFI /mnt/nixos/boot
```
9. Generate an initial configuration (you'll want it to enable WiFi connectivity and a web browser at least):
```bash
nixos-generate-config --root /mnt/nixos
# /etc/nixos/configuration.nix
# /etc/nixos/hardware-configuration.nix
```
10. Do the installation:
```bash
nixos-install --root /mnt/nixos
```
11. If everything went well:
```bash
reboot
```
12. Log into Github and generate an SSH key for authentication.
13. Clone and link an editable version of the configuration:
```bash
mkdir -p /data/andrew/sources # or in an alternate location, for now
git clone git@github.com:goromal/anixpkgs.git /data/andrew/sources/anixpkgs
cat /etc/nixos/hardware-configuration.nix > /data/andrew/sources/anixpkgs/pkgs/nixos/personal/[hardware-configuration.nix] # update link/headings in configuration.nix
sudo mv /etc/nixos/configuration.nix /etc/nixos/old.configuration.nix
sudo mv /etc/nixos/hardware-configuration.nix /etc/nixos/old.hardware-configuration.nix
sudo ln -s /data/andrew/sources/anixpkgs/pkgs/nixos/personal/configuration.nix /etc/nixos/configuration.nix
```
14. Make other needed updates to the configuration, then apply:
```bash
sudo nixos-rebuild boot
sudo reboot
```

## Build a NixOS ISO Image

***TODO (untested)***; work out hardware configuration portion.

```bash
nixos-generate -f iso -c /path/to/personal/configuration.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
sudo dd if=/path/to/nixos.iso of=/dev/sdX bs=4M conv=fsync status=progress
```
