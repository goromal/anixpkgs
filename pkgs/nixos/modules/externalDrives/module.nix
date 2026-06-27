{
  config,
  lib,
  ...
}:
let
  cfg = config.machines.externalDrives;

  foreignFsTypes = [
    "ntfs"
    "ntfs-3g"
    "vfat"
    "exfat"
  ];

  uid = toString config.users.users.${cfg.user}.uid;
  gid = toString config.users.groups.${cfg.group}.gid;

  baseOpts = [
    "nofail"
    "x-systemd.automount"
    "x-systemd.idle-timeout=60"
    "x-systemd.device-timeout=10s"
  ];

  ownershipOpts = [
    "uid=${uid}"
    "gid=${gid}"
    "dmask=007"
    "fmask=117"
    "windows_names"
  ];

  driveModule = lib.types.submodule {
    options = {
      uuid = lib.mkOption {
        type = lib.types.str;
        description = "Filesystem UUID; the device is resolved via /dev/disk/by-uuid.";
      };
      fsType = lib.mkOption {
        type = lib.types.str;
        default = "ntfs-3g";
        description = "Mount filesystem type.";
      };
      extraOptions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra mount options appended for this drive.";
      };
    };
  };

  mkMount = name: drive: {
    name = "/mnt/${name}";
    value = {
      device = "/dev/disk/by-uuid/${drive.uuid}";
      fsType = drive.fsType;
      options =
        baseOpts
        ++ lib.optionals (lib.elem drive.fsType foreignFsTypes) ownershipOpts
        ++ drive.extraOptions;
    };
  };
in
{
  options.machines.externalDrives = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Auto-mount known external drives at /mnt/<name> when connected.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "andrew";
      description = "Owner of foreign-filesystem mounts.";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "dev";
      description = "Group owner of foreign-filesystem mounts.";
    };
    drives = lib.mkOption {
      type = lib.types.attrsOf driveModule;
      default = {
        seagate.uuid = "A4E83FF7E83FC5F8";
        aegis.uuid = "0259FC5C6268D54B";
      };
      description = "Known external drives keyed by mount-point name under /mnt.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "ntfs" ];
    fileSystems = lib.mapAttrs' mkMount cfg.drives;
  };
}
