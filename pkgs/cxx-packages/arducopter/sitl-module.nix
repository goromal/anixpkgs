{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.ardupilot-sim;
  defaults = {
    LAT = "34.381441";
    LON = "-118.580861";
    ALT = "417.0";
    HDG = "0.0";
    UND = "0.0";
  };
  simEnvFileName = "sim.env";
  simEnvFile = pkgs.writeText "${simEnvFileName}" ''
    LAT=${defaults.LAT}
    LON=${defaults.LON}
    ALT=${defaults.ALT}
    HDG=${defaults.HDG}
    UND=${defaults.UND}
  '';
  simEnvSetupScript = pkgs.writeShellScriptBin "setup-sim-env" ''
    ENV_FILE="${cfg.rootDir}/${simEnvFileName}"
    if [ ! -f "$ENV_FILE" ]; then
      echo "LAT=${defaults.LAT}" > "$ENV_FILE"
      echo "LON=${defaults.LON}" >> "$ENV_FILE"
      echo "ALT=${defaults.ALT}" >> "$ENV_FILE"
      echo "HDG=${defaults.HDG}" >> "$ENV_FILE"
      echo "UND=${defaults.UND}" >> "$ENV_FILE"
      chown ${cfg.user}:${cfg.group} "$ENV_FILE"
    fi
  '';
  paramsFile = pkgs.writeText "sitl-params.parm" (
    (lib.optionalString (cfg.baseDefaultsFile != null) (builtins.readFile cfg.baseDefaultsFile + "\n"))
    + (lib.concatStringsSep "\n" cfg.parameters)
    + "\n"
  );
  haveDefaults = cfg.baseDefaultsFile != null || cfg.parameters != [ ];
  simExecScript = pkgs.writeShellScriptBin "sim-exec-start" ''
    source "${cfg.rootDir}/${simEnvFileName}"
    exec ${cfg.package}/bin/arducopter \
      --model=${cfg.platform} \
      --home="$LAT,$LON,$ALT,$HDG" \
      --config=undulation:$UND \
      -S -I 0 ${lib.optionalString haveDefaults "\\\n      --defaults ${paramsFile}"}
  '';
in
{
  options.services.ardupilot-sim = {
    enable = lib.mkEnableOption "Enable Arducopter SITL";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The ardupilot package to use";
    };
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root service directory";
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Service owner user";
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = "Service owner group";
    };
    platform = lib.mkOption {
      type = lib.types.str;
      description = "Vehicle platform/frame type passed to the SITL --model flag (default: quad)";
      default = "quad";
    };
    baseDefaultsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Base parameter defaults file prepended to `parameters` (e.g. ArduPilot's
        Tools/autotest/default_params/copter.parm, which carries the frame class
        and sensor-calibration values SITL needs to pass prearm checks). Entries
        in `parameters` override it (last assignment wins).
      '';
    };
    parameters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        List of Ardupilot parameter assignments (e.g., "DISARM_DELAY 0") written
        to a defaults file passed to the SITL via --defaults.
      '';
      default = [ ];
      example = [
        "DISARM_DELAY 0"
        "FRAME_CLASS 1"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.rootDir} - ${cfg.user} ${cfg.group}"
      "Z ${cfg.rootDir} - ${cfg.user} ${cfg.group}"
      "C ${cfg.rootDir}/${simEnvFileName} 0666 ${cfg.user} ${cfg.group} ${simEnvFile}"
      "d ${cfg.rootDir}/logs - ${cfg.user} ${cfg.group}"
      "f ${cfg.rootDir}/logs/* - - - 0666"
      "r! ${cfg.rootDir}/eeprom.bin - ${cfg.user} ${cfg.group}"
      "r! ${cfg.rootDir}/persistent.dat - ${cfg.user} ${cfg.group}"
      "R ${cfg.rootDir}/terrain - ${cfg.user} ${cfg.group}"
      "R ${cfg.rootDir}/scripts - ${cfg.user} ${cfg.group}"
    ];
    systemd.services.ardusitl = {
      enable = true;
      description = "Arducopter SITL";
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${simEnvSetupScript}/bin/setup-sim-env";
        ExecStart = "${simExecScript}/bin/sim-exec-start";
        WorkingDirectory = "${cfg.rootDir}";
        ReadWritePaths = [ "${cfg.rootDir}" ];
        User = cfg.user;
        Group = cfg.group;
        PrivateTmp = true;
        AmbientCapabilities = [ "CAP_KILL" ];
        CapabilityBoundingSet = [ "CAP_KILL" ];
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
