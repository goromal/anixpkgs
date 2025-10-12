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
home-manager https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz
nixpkgs https://nixos.org/channels/nixos-25.05
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

## Build and Deploy a Raspberry Pi NixOS SD Configuration

Since the hardware configuration for the Raspberry Pi is well understood, it makes sense to skip the installer step and deploy a fully-fledged clusure instead.

```bash
nixos-generate -f sd-aarch64 --system aarch64-linux -c /path/to/anixpkgs/pkgs/nixos/configurations/config.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
nix-shell -p zstd --run "unzstd -d /nix/store/path/to/image.img.zst"
```

```bash
sudo dd if=/path/to/image.img of=/dev/sdX bs=4096 conv=fsync status=progress
```

On the Pi, connect to the internet, copy over SSH keys (maybe no need for `/root/.ssh/`) and then set up the Nix channel(s):

```bash
sudo nix-channel --add https://nixos.org/channels/nixos-[NIXOS-VERSION] nixos
sudo nix-channel --update
```

Note that the `nixos-generate` step may not have "aarch-ified" the `anixpkgs` packages (that's something for me to look into) so the `anix-upgrade` setup steps are especially important:

- Make a `~/sources` directory
- Symlink the configuration file even if it doesn't exist yet
- Run `anix-upgrade` to aarch-ify everything

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

***Note***: You can replace steps 1-8 with a `kexec` kernel load and disk formatting with `disko`:
- [kexec directions](https://github.com/nix-community/nixos-images#kexec-tarballs)
- [disko directions](https://github.com/nix-community/disko)

1. Build the installation ISO with `NIXPKGS_ALLOW_UNFREE=1 nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=pkgs/nixos/installers/personal.nix`
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

...

13. Log into Github and generate an SSH key for authentication.
14. Clone and link an editable version of the configuration:
```bash
mkdir -p /data/andrew/sources # or in an alternate location, for now
git clone git@github.com:goromal/anixpkgs.git /data/andrew/sources/anixpkgs
cat /etc/nixos/hardware-configuration.nix > /data/andrew/sources/anixpkgs/pkgs/nixos/hardware/[hardware-configuration.nix] # update link/headings in configuration.nix
sudo mv /etc/nixos/configuration.nix /etc/nixos/old.configuration.nix
sudo mv /etc/nixos/hardware-configuration.nix /etc/nixos/old.hardware-configuration.nix
sudo ln -s /data/andrew/sources/anixpkgs/pkgs/nixos/configurations/[your-configuration.nix] /etc/nixos/configuration.nix
```
1.   Make other needed updates to the configuration, then apply:
```bash
sudo nixos-rebuild boot
sudo reboot
```

## Upgrading NixOS versions with `anixpkgs`

Aside from the source code changes in `anixpkgs`, ensure that your channels have been updated **for the root user**:

```bash
# e.g., upgrading to 25.05:
home-manager https://github.com/nix-community/home-manager/archive/release-25.05.tar.gz
nixos https://nixos.org/channels/nixos-25.05
nixpkgs https://nixos.org/channels/nixos-25.05
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

## Build a NixOS ISO Image

***TODO (untested)***; work out hardware configuration portion.

```bash
nixos-generate -f iso -c /path/to/personal/configuration.nix [-I nixpkgs=/path/to/alternative/nixpkgs]
```

```bash
sudo dd if=/path/to/nixos.iso of=/dev/sdX bs=4M conv=fsync status=progress
```

