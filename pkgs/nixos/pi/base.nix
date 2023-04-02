# https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi
{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; };
{
    imports = [
        ../base.nix
    ];

    # boot.kernelPackages = mkForce config.boot.zfs.package.latestCompatibleLinuxPackages;

    # https://github.com/NixOS/nixpkgs/issues/154163
    nixpkgs.overlays = [
        (final: super: {
            # modprobe: FATAL: Module sun4i-drm not found
            makeModulesClosure = x:
                super.makeModulesClosure (x // { allowMissing = true; });
        })
    ];

    # Grub is used on Raspberry Pi
    boot.loader.systemd-boot.enable = mkForce false;

    environment.systemPackages = [
        libraspberrypi
    ];

    fileSystems = {
        "/" = {
            device = "/dev/disk/by-label/NIXOS_SD";
            fsType = "ext4";
            options = [ "noatime" ];
        };
    };

    home-manager.users.andrew = {
        # home.packages = [];
    };

    # Use 1GB of additional swap memory in order to not run out of memory
    # when installing lots of things while running other things at the same time.
    swapDevices = [ { device = "/swapfile"; size = 1024; } ];
}
