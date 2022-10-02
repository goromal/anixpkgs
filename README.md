# anixpkgs

A collection of personal (or otherwise personally useful) repositories packaged as Nix overlays.

The philosophy for the library implementations (and, sometimes, re-implementations) is to facilitate:

- Implementation and notation consistency
- Seamless interoperability
- Quick idea and calculation prototyping

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
  python-with-my-packages = pkgs.python38.withPackages (p: with p; [
    numpy
    matplotlib
    geometry
    pyceres
  ]);
in
python-with-my-packages.env
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
      3. Free spae following (MiB): Rest
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
9. Generate an initial configuration:
```bash
nixos-generate-config --root /mnt/nixos
# /etc/nixos/configuration.nix
# /etc/nixos/hardware-configuration.nix
```
10. Edit `/etc/nixos/configuration.nix` to the following, which will set up the basic boilerplate for all machines:
```nix
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
  anixpkgs_src = builtins.fetchGit {
    url = "git@github.com:goromal/anixpkgs.git";
    ref = "[DESIRED_REF]";
    rev = "[OPTIONAL_DESIRED_REV]";
  };
in
  imports = [
    ./hardware-configuration.nix
    "${anixpkgs_src}/pkgs/nixos/base.nix"
  ];
  networking.hostName = "atorgesen-laptop";
  system.stateVersion = whatever-it-was-before;
}
```
11. Do the installation:
```bash
nixos-install --root /mnt/nixos
```
12. If everything went well:
```bash
reboot
```
13. Log into your user, then clone and link an editable version of the configuration:
```bash
mkdir -p /data/andrew/sources
git clone git@github.com:goromal/anixpkgs.git /data/andrew/sources/anixpkgs
cat /etc/nixos/hardware-configuration.nix > /data/andrew/sources/anixpkgs/pkgs/nixos/personal/[hardware-configuration.nix] # update link/headings in configuration.nix
sudo mv /etc/nixos/configuration.nix /etc/nixos/old.configuration.nix
sudo mv /etc/nixos/hardware-configuration.nix /etc/nixos/old/hardware-configuration.nix
sudo ln -s /data/andrew/sources/anixpkgs/pkgs/nixos/personal/configuration.nix /etc/nixos/configuration.nix
nrs
```
