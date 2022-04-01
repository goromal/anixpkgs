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
            virtualisation.forwardPorts = [
                # forward local port 2222 -> 22, to ssh into the VM
                { from = "host"; host.port = 2222; guest.port = 22; }
            ];
        };
    };
    skipLint = true;
    testScript = ''
        base.allow_reboot = True
        base.start()
        base.wait_for_unit("default.target")
        base.shell_interact()
    '';
})
