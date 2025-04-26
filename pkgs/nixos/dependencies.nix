let
  nixos-version = (builtins.readFile ../../NIXOS_VERSION);
  anixpkgs-version = (builtins.readFile ../../ANIX_VERSION);
  anixpkgs-meta = (builtins.readFile ../../ANIX_META);
in rec {
  local-build = true;
  inherit nixos-version; # Should match the channel in <nixpkgs>
  inherit anixpkgs-version;
  inherit anixpkgs-meta;
  anixpkgs-src = if local-build then
    ../../default.nix
  else
    (builtins.fetchTarball
      "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anixpkgs-version}.tar.gz");
  anixpkgs = import anixpkgs-src { };
  unstable = import (builtins.fetchTarball
    "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") { };
  service-ports = import ./service-ports.nix;
  mkProfileConfig = baseCfg:
    let
      mkOneshotTimedOrchService =
        { name, jobShellScript, timerCfg, readWritePaths ? [ "/" ] }: {
          systemd.timers."${name}" = {
            description = "${name} trigger timer";
            wantedBy = [ "timers.target" ];
            timerConfig = timerCfg // { Unit = "${name}.service"; };
          };
          systemd.services."${name}" = {
            enable = true;
            description = "${name} oneshot service";
            serviceConfig = {
              Type = "oneshot";
              ExecStart =
                "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${jobShellScript}'";
              ReadWritePaths = readWritePaths;
            };
          };
        };
    in (builtins.foldl' (acc: set: anixpkgs.lib.recursiveUpdate acc set) {
      machines.base = baseCfg;
    } (map (x: (mkOneshotTimedOrchService x)) baseCfg.timedOrchJobs));
}
