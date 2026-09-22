# Catalog of all known LAN build machines.
# Reference entries by key in machines.base.remoteBuilders.
# Each entry maps to a nix.buildMachines item, plus hostPublicKey: the SSH host
# key that pc-base.nix installs system-wide for every machine that references
# the builder. Distributed builds run as root, which does not consult any user's
# known_hosts file, so a builder without a recorded key cannot be reached.
# Set hostPublicKey to null when the key has not been recorded yet.
{
  personal-inspiron = {
    hostName = "atorgesen-inspiron.local";
    sshUser = "andrew";
    sshKey = "/data/andrew/.ssh/id_rsa";
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMvnNeJsnhfxvH79VANgM058I0oTDO8teKu2ZrEhqKhp";
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
    hostPublicKey = null;
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
    hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEdoj0khQi8tFw2ZOeGPaPzVJgJZ9f0QOkZYpe8FFYhy";
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
