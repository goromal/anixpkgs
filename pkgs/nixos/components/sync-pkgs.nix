{ pkgs, config, lib, ... }:
with pkgs;
with lib; # ^^^^
# with import ../dependencies.nix { inherit config; };
let
  cfg = config.mods.opts;
  mkSyncService = { name, cloudname, dirname, homeDir }:
   {
      systemd.user.services."${name}-sync" = {
        Unit.Description = "${name} cloud sync service";
        Unit.After = [ "network-online.target" ];
        Service = {
          Type = "simple";
          ExecStart = "ha/bin/execute-sync";
          ExecStop = "da/bin/stop-sync";
          Restart = "always";
          RestartSec = 30;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  # cloud_daemon_list = (builtins.filter (x: x.daemonmode) cfg.cloudDirs);
  cloud_daemon_list = (builtins.filter (x: x.daemonmode) [ # ^^^^
        {
          name = "configs";
          cloudname = "dropbox:configs";
          dirname = "${opts.homeDir}/configs";
          daemonmode = true;
        }
        {
          name = "secrets";
          cloudname = "dropbox:secrets";
          dirname = "${opts.homeDir}/secrets";
          daemonmode = true;
        }
        {
          name = "games";
          cloudname = "dropbox:games";
          dirname = "${opts.homeDir}/games";
          daemonmode = false;
        }
        {
          name = "data";
          cloudname = "box:data";
          dirname = "${opts.homeDir}/data";
          daemonmode = true;
        }
        {
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "${opts.homeDir}/Documents";
          daemonmode = true;
        }
      ]);
  # cloud_daemon_list = [{name = "hey"; cloudname = "you"; dirname = "are";}];
  cloudDaemonServices =
    map (x: (mkSyncService {name = x.name; cloudname = x.cloudname; dirname = x.dirname; homeDir = cfg.homeDir;})) cloud_daemon_list;
  # cloudDaemonServices =
  #   map (x: (mkSyncService {name = x.name; cloudname = x.cloudname; dirname = x.dirname; homeDir = cfg.homeDir;})) [
  #     {name = "hey"; cloudname = "you"; dirname = "are";}
  #   ];
  # cloudDaemonServices = [
  #     {system.stateVersion = lib.mkForce "45";}
  #   ];
in {
  config = mkIf true (foldl' (acc: set: recursiveUpdate acc set) { } cloudDaemonServices);
  # config = (mkSyncService {name = "secrets"; cloudname = "dropbox"; dirname = "secrets"; homeDir = cfg.homeDir;});
}
