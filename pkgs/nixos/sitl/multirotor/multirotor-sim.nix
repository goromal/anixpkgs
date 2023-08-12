{ config, pkgs, lib, ... }:
pkgs.nixosTest ({
    name = "MultirotorSim";
    nodes = {
        fcm = { ... }: {
            imports = [ ./fcm.nix ];
            virtualisation.graphics = true;
            virtualisation.vlans = [ 1 ];
            virtualisation.memorySize = 4 * 1024;
            virtualisation.diskSize = 16 * 1024;
            virtualisation.cores = 4;
            virtualisation.forwardPorts = [
                { from = "host"; host.port = 2222; guest.port = 22; }
            ];
        };
    };
    skipLint = true;
    testScript = ''
        multirotorFcm.allow_reboot = True
        multirotorFcm.start()
        multirotorFcm.wait_for_unit("graphical.target")
        multirotorFcm.shell_interact()
    '';
})
