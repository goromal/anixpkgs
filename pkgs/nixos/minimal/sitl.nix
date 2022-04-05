{ config, pkgs, lib, ... }:
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix
pkgs.nixosTest ({
    name = "MachineSITL";
    system = "x86_64-linux";
    nodes = {
        testMachine = { ... }: {
            imports = [
                ./configuration.nix
            ];
            virtualisation.graphics = false;
            virtualisation.memorySize = 8 * 1024;
            virtualisation.diskSize = 8 * 1024;
            virtualisation.cores = 6;
        };
    };
    skipLint = true;
    testScript = ''
        testMachine.allow_reboot = True
        testMachine.start()
        testMachine.wait_for_unit("default.target")
    '';
})
