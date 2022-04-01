{ config, pkgs, lib, ... }:
let
    shared = {
        virtualisation.graphics = false;
        virtualisation.memorySize = 8192;
        virtualisation.diskSize = 8192;
        virtualisation.cores = 6;
    };
    sitlModule = [
        shared
        ./configuration.nix
    ];
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix
in pkgs.nixosTest ({
    name = "MachineSITL";
    system = "x86_64-linux";
    nodes = {
        testMachine = { ... }: {
            imports = sitlModule;
        };
    };
    skipLint = true;
    testScript = ''
        testMachine.allow_reboot = True
        testMachine.start()
        testMachine.wait_for_unit("default.target")
    '';
})
