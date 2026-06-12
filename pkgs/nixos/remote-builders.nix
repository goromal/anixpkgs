# Catalog of all known LAN build machines.
# Reference entries by key in machines.base.remoteBuilders.
# Each entry maps directly to a nix.buildMachines item.
{
  personal-inspiron = {
    hostName = "atorgesen-inspiron.local";
    sshUser = "andrew";
    sshKey = "/data/andrew/.ssh/id_rsa";
    # x86_64-linux natively; aarch64-linux via binfmt emulation (pc-base.nix)
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [
      "nixos-test"
      "benchmark"
      "big-parallel"
    ];
  };
  personal-panasonic = {
    hostName = "atorgesen-panasonic.local";
    sshUser = "andrew";
    sshKey = "/data/andrew/.ssh/id_rsa";
    # x86_64-linux natively; aarch64-linux via binfmt emulation (pc-base.nix)
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [
      "nixos-test"
      "benchmark"
      "big-parallel"
    ];
  };
  personal-dell = {
    hostName = "atorgesen-dell.local";
    sshUser = "andrew";
    sshKey = "/data/andrew/.ssh/id_rsa";
    # x86_64-linux natively; aarch64-linux via binfmt emulation (pc-base.nix)
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maxJobs = 4;
    speedFactor = 2;
    supportedFeatures = [
      "nixos-test"
      "benchmark"
      "big-parallel"
    ];
  };
}
