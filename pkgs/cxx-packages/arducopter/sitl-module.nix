{ pkgs, config, lib, ... }:
# ^^^^ TODO
with lib;
with lib.trivial;
let
  cfg = config.services.ardupilot-sim;

  # Define the path to the mutable configuration directory, within the rootDir or its subdirectory
  runtimeConfigDir =
    "${cfg.rootDir}/config"; # You can change 'config' to any subdirectory name

  # Use the writeText function to create a file in the Nix store with the desired contents
  startingLocationEnvFile = pkgs.writeText "starting-location.env" ''
    LAT=${toString cfg.initialPose.lat}
    LON=${toString cfg.initialPose.lon}
    ALT=${toString cfg.initialPose.alt}
    HDG=${toString cfg.initialPose.heading}
  '';

  simEnvSetupScript = pkgs.writeShellScriptBin "setup-sim-start-loc" ''
    #!/bin/sh

    exec > /tmp/prestart.log 2>&1
    echo "Starting pre-start script"

    set -euo pipefail

    ENV_FILE="${runtimeConfigDir}/starting-location.env"

    # Check if the environment file already exists
    if [ ! -f "$ENV_FILE" ]; then
      echo "should create ENV FILE"
      # Write the environment variables to the starting-location.env file
      echo "LAT=${toString cfg.initialPose.lat}" > "$ENV_FILE"
      echo "LON=${toString cfg.initialPose.lon}" >> "$ENV_FILE"
      echo "ALT=${toString cfg.initialPose.alt}" >> "$ENV_FILE"
      echo "HDG=${toString cfg.initialPose.heading}" >> "$ENV_FILE"

      # Ensure the file is owned by the 'andrew' user and group
      chown andrew:andrew "$ENV_FILE"
    fi
    echo "Finished pre-start script"
  '';

  simStartScript = pkgs.writeShellScriptBin "ardupilot-sim-start" ''
    #!/bin/sh
    set -e

    # Load environment variables from the environment file
    source /data/andrew/ardupilot-sim/config/starting-location.env

    # Debug: Print environment variables to a file
    echo "LAT=$LAT, LON=$LON, ALT=$ALT, HDG=$HDG" > /tmp/ardupilot-debug-env

    # Run the ardupilot executable with the environment variables
    exec ${cfg.package}/bin/ardupilot \
      --model=${cfg.model} \
      --home="$LAT,$LON,$ALT,$HDG" \
      --config=undulation:${toString cfg.undulation} \
      -S -I ${toString cfg.asset-id} --serial5=sim:vicon: \
      ${lib.optionalString (cfg.params != "") "--defaults ${cfg.params}"} \
      ${lib.optionalString (cfg.speedUp != null) "--speedup ${cfg.speedUp}"} \
      ${lib.optionalString cfg.wipe "--wipe"}
  '';

  # This port is specified from ardupilot. Do not change this value unless you know what you are doing.
  defaultPort = 5760;
  customTypes = {
    ardupilotPort = mkOptionType {
      name = "port";
      description = "Ardupilot SITL port number";
      check = x: isInt x && x >= defaultPort && mod x 10 == 0;
      merge = mergeEqualOption;
    };
    latitude = mkOptionType {
      name = "latitude";
      description = "Geodetic latitude";
      check = x: isFloat x && x >= -90.0 && x <= 90.0;
      merge = mergeEqualOption;
    };
    longitude = mkOptionType {
      name = "longitude";
      description = "Geodetic longitude";
      check = x: isFloat x && x >= -180.0 && x <= 180.0;
      merge = mergeEqualOption;
    };
    heading = mkOptionType {
      name = "heading";
      description = "Heading";
      check = x: isFloat x && x >= 0.0 && x <= 360.0;
      merge = mergeEqualOption;
    };
    # This is used to specify which andrew defined ardupilot version to use.
    type = types.enum (builtins.attrNames pkgs.andrew.ardupilot);
    # The model type to simulate.
    model =
      types.enum [ "heli" "quad" "agentsim" "copter" "plane" "quadplane" ];
  };

in {
  options.services.ardupilot-sim = with types; {
    enable = mkEnableOption "Ardupilot heli Simulator";
    rootDir = mkOption {
      type = types.str;
      description = "Ardupilot sim directory for data and configuration";
      default = "/data/andrew/ardupilot-sim";
    };
    asset-id = mkOption {
      type = types.int;
      default = 2;
      description = ''
        Define the asset ID, which will be taken as the instance number.
      '';
    };
    initialPose = {
      lat = mkOption {
        type = customTypes.latitude;
        description = "The initial latitude of the ardupilot simulator";
        default = 33.467945;
      };
      lon = mkOption {
        type = customTypes.longitude;
        description = "The initial longitude of the ardupilot simulator";
        default = -117.563854;
      };
      alt = mkOption {
        type = types.float;
        description = "The initial altitude of the ardupilot simulator";
        default = 81.0;
      };
      heading = mkOption {
        type = customTypes.heading;
        description = "The initial heading of the ardupilot simulator";
        default = 45.0;
      };
    };
    undulation = mkOption {
      type = types.int;
      default = -34;
      description = "The undulation HAE - MSL at initial location";
    };
    port = mkOption {
      type = customTypes.ardupilotPort;
      description = "The port to run the ardupilot SITL on";
      default = defaultPort;
    };
    params = mkOption {
      type = types.path;
      description = "Absolute path to default mavlink parameters";
    };
    type = mkOption {
      type = customTypes.type;
      description = "Which andrew NixPkgs defined Ardupilot type to simulate";
    };
    model = mkOption {
      type = customTypes.model;
      description = "The model air frame type to simulate";
    };
    package = mkOption {
      type = types.package;
      description = "The ArduPilot package to run";
      default = pkgs.andrew.ardupilot."${cfg.type}".sim;
    };
    logDir = mkOption {
      type = types.nullOr types.str;
      description = "Directory that symlinks to the simulated logs";
      default = null;
    };
    speedUp = mkOption {
      type = types.nullOr types.str;
      description = "Speed up factor";
      default = null;
    };
    wipe = mkOption {
      type = types.bool;
      description = "Wipe the EEPROM on startup";
      default = false;
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir}          - andrew andrew"
      "d ${cfg.rootDir}/var      - andrew andrew"
      "d ${runtimeConfigDir}     - andrew andrew"
      "d ${cfg.rootDir}/var/data - andrew andrew"
      "r! ${cfg.rootDir}/var/data/eeprom.bin - andrew andrew"
      "r! ${cfg.rootDir}/var/data/persistent.dat - andrew andrew"
      "R ${cfg.rootDir}/var/data/terrain - andrew andrew"
      "R ${cfg.rootDir}/var/data/scripts - andrew andrew"
      "d ${cfg.rootDir}/var/data/logs - andrew andrew"
      "Z ${cfg.rootDir}          - andrew andrew"
      "L ${cfg.rootDir}/var/data/scripts - - - - ${cfg.package}/scripts"
      "C ${runtimeConfigDir}/starting-location.env 0666 andrew andrew ${startingLocationEnvFile}"
    ] ++ (if cfg.logDir == null then
      [ ]
    else [
      "d ${cfg.logDir}          - andrew andrew"
      "L+ ${cfg.logDir} - - - -  ${cfg.rootDir}/var/data/logs"
      "f ${cfg.logDir}/* - - - 0666"
    ]);

    systemd.services.ardupilot-sim = {
      enable = true;
      description = "Simulator for the Ardupilot Heli flight controller";
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${simEnvSetupScript}/bin/setup-sim-start-loc";
        ExecStart = "${simStartScript}/bin/ardupilot-sim-start";

        WorkingDirectory = "${cfg.rootDir}/var/data";
        PrivateTmp = true;
        ReadWritePaths = [ "${cfg.rootDir}/var/data" ];

        User = "andrew";
        Group = "andrew";

        AmbientCapabilities = [ "CAP_KILL" ];
        CapabilityBoundingSet = [ "CAP_KILL" ];
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
