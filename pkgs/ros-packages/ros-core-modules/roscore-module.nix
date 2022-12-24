{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
    cfg = config.services.roscore;
in {
    options.services.roscore = {
        enable = mkEnableOption "Enable the roscore module.";
        port = mkOption {
            type = types.port;
            default = 11311;
            description = ''
                Port that the ROS master node will bind to.
            '';
        };
        hostname = mkOption {
            type = types.str;
            default = "localhost";
            description = ''
                Value of the ROS_HOSTNAME environment variable. Defaults to
                <option>networking.hostName</option>.
            '';
        };
        rosHomeDir = mkOption {
            type = types.str;
            default = "/data/andrew/ros";
            description = ''
                ROS home directory for log storage.
            '';
        };
    };

    config = mkIf cfg.enable {
        systemd.services.roscore = {
            description = "ROS master node";
            serviceConfig = {
                Type = "exec";
                ExecStart = let
                    env = with pkgs.rosPackages.noetic; buildEnv {
                        name = "roscore-env";
                        paths = [ roslaunch ];
                    };
                    in "${env}/bin/roscore -p ${builtins.toString cfg.port}";
                User = "andrew";
                Group = "dev";
                StateDirectory = "ros";
            };
            wantedBy = [ "multi-user.target" ];
            environment = {
                ROS_HOSTNAME = cfg.hostname;
                ROS_MASTER_URI = "https://${cfg.hostname}:${builtins.toString cfg.port}/";
                ROS_HOME = cfg.rosHomeDir;
            };
        };
    };
}
