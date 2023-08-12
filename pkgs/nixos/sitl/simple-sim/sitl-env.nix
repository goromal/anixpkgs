{
    name = "SimpleSim";
    nodes = {
        fcm = { ... }: {
            imports = [ ./onboard-computer.nix ];
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
    testScript = ''
        onboard.allow_reboot = True
        onboard.start()
        onboard.wait_for_unit("graphical.target")
        onboard.shell_interact()
    '';
}
