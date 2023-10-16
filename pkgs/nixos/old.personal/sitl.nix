{ config, pkgs, lib, ... }:
# https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/qemu-vm.nix
pkgs.nixosTest ({
  name = "MachineSITL";
  system = "x86_64-linux";
  nodes = {
    testMachine = { ... }: {
      imports = [ ./configuration.nix ];
      virtualisation.graphics = true;
      virtualisation.memorySize = 8 * 1024;
      virtualisation.diskSize = 25 * 1024;
      virtualisation.cores = 6;
      virtualisation.forwardPorts = [
        # forward local port 2222 -> 22, to ssh into the VM
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
  };
  skipLint = true;
  testScript = ''
    personal.allow_reboot = True
    personal.start()
    personal.wait_for_unit("default.target")
    personal.shell_interact()
  '';
})
