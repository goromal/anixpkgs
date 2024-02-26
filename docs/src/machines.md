# Machine Management

***These notes are still a work-in-progress and are currently largely for my personal use only.***

## Home-Manager Example

1. Install Nix standalone:
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```
3. Set proper Nix settings in `/etc/nix/nix.conf`:
```
substituters = https://cache.nixos.org/ https://github-public.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc=
narinfo-cache-positive-ttl = 0
narinfo-cache-negative-ttl = 0
experimental-features = nix-command flakes auto-allocate-uids
```
4. Add these Nix channels via `nix-channel --add URL NAME`:
```bash
$ nix-channel --list
home-manager https://github.com/nix-community/home-manager/archive/release-23.05.tar.gz
nixpkgs https://nixos.org/channels/nixos-23.05
```
5. Install home-manager: https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

Example `home.nix` file for personal use:

```nix
{ config, pkgs, lib, ... }:
let
  user = "andrew";
  homedir = "/home/${user}";
in with import ../dependencies.nix { inherit config; }; {
  home.username = user;
  home.homeDirectory = homedir;
  home.stateVersion = nixos-version;
  programs.home-manager.enable = true;

  imports = [
    [ANIX_SRC]/pkgs/nixos/components/base-pkgs.nix
    [ANIX_SRC]/pkgs/nixos/components/base-dev-pkgs.nix
    [ANIX_SRC]/pkgs/nixos/components/x86-rec-pkgs.nix
    [ANIX_SRC]/pkgs/nixos/components/x86-graphical-pkgs.nix
    [ANIX_SRC]/pkgs/nixos/components/x86-graphical-dev-pkgs.nix
    [ANIX_SRC]/pkgs/nixos/components/x86-graphical-rec-pkgs.nix
  ];

  mods.base.standalone = true;
  mods.base.homeDir = homedir;
}

```

`*-rec-*` packages can be removed for non-recreational use.

Symlink to `~/.config/home-manager/home.nix`.

Corresponding `~/.bashrc`:

```bash
export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
. "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
export NIXPKGS_ALLOW_UNFREE=1
# alias code='codium'
# eval "$(direnv hook bash)"
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
cat /etc/nixos/hardware-configuration.nix > /data/andrew/sources/anixpkgs/pkgs/nixos/hardware/[hardware-configuration.nix] # update link/headings in configuration.nix
sudo mv /etc/nixos/configuration.nix /etc/nixos/old.configuration.nix
sudo mv /etc/nixos/hardware-configuration.nix /etc/nixos/old.hardware-configuration.nix
sudo ln -s /data/andrew/sources/anixpkgs/pkgs/nixos/configurations/[your-configuration.nix] /etc/nixos/configuration.nix
```
14. Make other needed updates to the configuration, then apply:
```bash
sudo nixos-rebuild boot
sudo reboot
```

### Cloud Syncing

The following mount points are recommended (using [rclone](https://rclone.org/) to set up):

- `dropbox:secrets` -> `rclone copy` -> `~/secrets`
- `dropbox:configs`-> `rclone copy` -> `~/configs`
- `dropbox:Games` -> `rclone copy` -> `~/games`
- `box:data` -> `rclone copy` -> `~/data`
- `box:.devrc` -> `rclone copy` -> `~/.devrc`
- `drive:Documents` -> `rclone copy` -> `~/Documents`

## Build a NixOS ISO Image

***TODO (untested)***; work out hardware configuration portion.

```bash
nixos-generate -f iso -c /path/to/personal/configuration.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
sudo dd if=/path/to/nixos.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

