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
