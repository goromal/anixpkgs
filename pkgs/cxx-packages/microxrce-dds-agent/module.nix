{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.microxrce-agent;
  # Disable the FastDDS shared-memory transport for the agent's DDS
  # participant. SHM segments are not accessible across Unix users, which
  # silently breaks data delivery to ROS2 nodes running as a different user
  # than the agent (discovery still works, so topics appear but carry no
  # samples). Loopback UDP works for any local subscriber.
  udpOnlyProfile = pkgs.writeText "microxrce-agent-udp-only-profile.xml" ''
    <?xml version="1.0" encoding="UTF-8" ?>
    <profiles xmlns="http://www.eprosima.com/XMLSchemas/fastRTPS_Profiles">
      <transport_descriptors>
        <transport_descriptor>
          <transport_id>udp_only</transport_id>
          <type>UDPv4</type>
        </transport_descriptor>
      </transport_descriptors>
      <participant profile_name="udp_only_participant" is_default_profile="true">
        <rtps>
          <userTransports>
            <transport_id>udp_only</transport_id>
          </userTransports>
          <useBuiltinTransports>false</useBuiltinTransports>
        </rtps>
      </participant>
    </profiles>
  '';
in
{
  options.services.microxrce-agent = {
    enable = lib.mkEnableOption "enable Micro XRCE-DDS agent service";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The Micro XRCE-DDS agent package to use";
    };
    transportArgs = lib.mkOption {
      type = lib.types.str;
      description = ''
        Transport args to pass to the agent (e.g., "udp4 --port 2019" or
        "serial --dev /dev/ttyAMA0 --baudrate 921600")
      '';
    };
    user = lib.mkOption {
      type = lib.types.str;
      description = "Service owner user";
    };
    group = lib.mkOption {
      type = lib.types.str;
      description = "Service owner group";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.microxrce-agent = {
      enable = true;
      description = "Micro XRCE-DDS agent";
      environment = {
        FASTRTPS_DEFAULT_PROFILES_FILE = "${udpOnlyProfile}";
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/MicroXRCEAgent ${cfg.transportArgs}";
        Restart = "always";
        RestartSec = 1;
        User = cfg.user;
        Group = cfg.group;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
