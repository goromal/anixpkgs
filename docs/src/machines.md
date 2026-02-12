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
home-manager https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz
nixpkgs https://nixos.org/channels/nixos-25.11
```
5. Install home-manager: https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone

Example `home.nix` file for personal use:

```nix
{ config, pkgs, lib, ... }:
let
  user = "andrew";
  homedir = "/home/${user}";
  anixsrc = ./path/to/sources/anixpkgs/.;
in with import ../dependencies.nix; {
  home.username = user;
  home.homeDirectory = homedir;
  programs.home-manager.enable = true;

  imports = [
    "${anixsrc}/pkgs/nixos/components/opts.nix"
    "${anixsrc}/pkgs/nixos/components/base-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/base-dev-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-rec-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-graphical-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-graphical-dev-pkgs.nix"
    "${anixsrc}/pkgs/nixos/components/x86-graphical-rec-pkgs.nix"
  ];

  mods.opts.standalone = true;
  mods.opts.homeDir = homedir;
  mods.opts.homeState = "23.05";
  mods.opts.browserExec = "google-chrome-stable";
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

## Personal Machine Installation Instructions

*Sources*

- https://nixos.wiki/wiki/NixOS_Installation_Guide
- https://alexherbo2.github.io/wiki/nixos/install-guide/

1. Build the installation ISO with `NIXPKGS_ALLOW_UNFREE=1 nix build .#nixosConfigurations.installer-personal.config.system.build.isoImage`
2. Plug in a USB stick large enough to accommodate the image.
3. Find the right device with `lsblk` or `fdisk -l`. Replace `/dev/sdX` with the proper device (do not use `/dev/sdX1` or partitions of the disk; use the whole disk `/dev/sdX`).
4. Burn ISO to USB stick with `dd if=result/iso/[...]linux.iso of=/dev/sdX bs=4M status=progress conv=fdatasync`
5. On the new machine, one-time boot UEFI into the USB stick on the computer (will need to disable Secure Boot from BIOS first)
6. Login as the user `andrew`
7. Connect to the internet
8. Within the installer, run `sudo anix-install`
9. If everything went well, reboot
10. On the next reboot, login as user `andrew` again
11. Connect to the internet
12. Run `anix-init` 
13. Enjoy!

## JetPack Machine Installation Instructions

1. Build the installation ISO with `NIXPKGS_ALLOW_UNFREE=1 nix build .#nixosConfigurations.installer-jetpack.config.system.build.isoImage`
2. Plug in a USB stick large enough to accommodate the image.
3. Find the right device with `lsblk` or `fdisk -l`. Replace `/dev/sdX` with the proper device (do not use `/dev/sdX1` or partitions of the disk; use the whole disk `/dev/sdX`).
4. Burn ISO to USB stick with `dd if=result/iso/[...]linux.iso of=/dev/sdX bs=4M status=progress conv=fdatasync`
5. Insert the USB drive into the Jetson device. On the AGX devkits, I've had the best luck plugging into the USB-C slot above the power barrel jack. You may need to try a few USB options until you find one that works with both the UEFI firmware and the Linux kernel.
6. Press power / reset as needed. When prompted, press ESC to enter the UEFI firmware menu. In the "Boot Manager", select the correct USB device and boot directly into it.
7. Connect to the internet
8. Within the installer, run `sudo anix-install`
9.  If everything went well, reboot
10. On the next reboot, login as user `andrew` again
11. Connect to the internet
12. Run `anix-init` 
13. Enjoy!

## Upgrading NixOS versions with `anixpkgs`

Aside from the source code changes in `anixpkgs`, ensure that your channels have been updated **for the root user**:

```bash
# e.g., upgrading to 25.11:
home-manager https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz
nixos https://nixos.org/channels/nixos-25.11
nixpkgs https://nixos.org/channels/nixos-25.11
```

`sudo nix-channel --update`. Then upgrade with

```bash
anix-upgrade [source specification] --local --boot
```

### Cloud Syncing

The following mount points are recommended (using [rclone](https://rclone.org/) to set up):

- `dropbox:secrets` -> `rclone copy` -> `~/secrets`
- `dropbox:configs`-> `rclone copy` -> `~/configs`
- `dropbox:Games` -> `rclone copy` -> `~/games`
- `box:data` -> `rclone copy` -> `~/data`
- `box:.devrc` -> `rclone copy` -> `~/.devrc`
- `drive:Documents` -> `rclone copy` -> `~/Documents`

## Build a JetPack Installer ISO

Cross-compiled from x86_64. Requires `binfmt` support for aarch64 (enabled by default on NixOS with `boot.binfmt.emulatedSystems`).

```bash
nix build .#nixosConfigurations.installer-jetpack.config.system.build.isoImage
```

```bash
dd if=result/iso/[...]linux.iso of=/dev/sdX bs=4M status=progress conv=fdatasync
```

## Build a NixOS ISO Image

***TODO (untested)***; work out hardware configuration portion.

```bash
nixos-generate -f iso -c /path/to/personal/configuration.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
sudo dd if=/path/to/nixos.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

