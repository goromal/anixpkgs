{
  system ? builtins.currentSystem,
}:
let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anixpkgs-version = (builtins.readFile ../../ANIX_VERSION);
  anixpkgs-meta = (builtins.readFile ../../ANIX_META);
  flakeLock = builtins.fromJSON (builtins.readFile ../../flake.lock);
  lockedTarball =
    name:
    let
      node = flakeLock.nodes.${name}.locked;
    in
    builtins.fetchTarball {
      url = "https://github.com/${node.owner}/${node.repo}/archive/${node.rev}.tar.gz";
      sha256 = node.narHash;
    };
in
rec {
  local-build = false;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  inherit anixpkgs-version;
  inherit anixpkgs-meta;
  anixpkgs-src = if local-build then ../../default.nix else lockedTarball "anixpkgs-src";
  anixpkgs = import anixpkgs-src { inherit system; };
  unstable = import (lockedTarball "nixpkgs-unstable") { inherit system; };
  jetpackSrc = lockedTarball "jetpack-nixos";
  service-ports = import ./service-ports.nix;
  mkProfileConfig =
    baseCfg:
    let
      mkOneshotTimedOrchService =
        {
          name,
          jobShellScript,
          timerCfg,
          readWritePaths ? [ "/" ],
        }:
        {
          systemd.timers."${name}" = {
            description = "${name} trigger timer";
            wantedBy = [ "timers.target" ];
            timerConfig = timerCfg // {
              Unit = "${name}.service";
            };
          };
          systemd.services."${name}" = {
            enable = true;
            description = "${name} oneshot service";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${jobShellScript}'";
              ReadWritePaths = readWritePaths;
            };
          };
        };
    in
    (builtins.foldl' (acc: set: anixpkgs.lib.recursiveUpdate acc set) {
      machines.base = baseCfg;
    } (map (x: (mkOneshotTimedOrchService x)) baseCfg.timedOrchJobs));
}
