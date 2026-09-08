{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.brom;
  stateDir = "/var/lib/brom";
  secretFile = "${stateDir}/rpc-secret";
  sessionFile = "${stateDir}/aria2.session";
  aria2Conf = pkgs.writeText "brom-aria2.conf" ''
    enable-rpc=true
    rpc-listen-all=false
    rpc-listen-port=${builtins.toString cfg.aria2RpcPort}
    seed-time=0
    continue=true
    save-session=${sessionFile}
    input-file=${sessionFile}
    save-session-interval=60
    dir=${cfg.defaultDownloadDir}
    follow-torrent=true
  '';
in
{
  options.services.brom = {
    enable = lib.mkEnableOption "enable the brom torrent UI";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The brom package to use";
      default = anixpkgs.brom;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.brom;
    };
    aria2RpcPort = lib.mkOption {
      type = lib.types.port;
      description = "Localhost port for brom's aria2 JSON-RPC interface";
      default = service-ports.brom-aria2-rpc;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/brom";
    };
    # NB: dataDir intentionally sits under the Box-synced `data` cloudDir -- it
    # holds only brom.db, following the la-quiz-web/tester/navidrome convention. This
    # is the opposite of secretFile/sessionFile below, which must NEVER be cloud-synced
    # and therefore live under /var/lib/brom instead. Don't "fix" one to match the other.
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory holding brom.db";
      default = "${globalCfg.homeDir}/data/brom";
    };
    defaultDownloadDir = lib.mkOption {
      type = lib.types.str;
      description = "aria2's fallback download dir; every add overrides it";
      default = "${globalCfg.homeDir}/downloads";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Torrents";
        tag = "Content";
        path = "/brom/";
        description = "Search and download torrents";
        icon = "download";
        faviconSvg = anixpkgs.pkgData.icons.favicons.download.data;
      }
    ];

    # NB: upstream services.aria2 is deliberately not used. It hardcodes
    # User/Group = "aria2" with no override, which cannot write into the
    # arbitrary user-chosen destinations brom's directory picker allows, and
    # would leave downloads owned aria2:aria2 and unmodifiable by andrew.
    systemd.services.brom-aria2 = {
      enable = true;
      description = "brom aria2 daemon";
      after = [ "network.target" ];
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        StateDirectory = "brom";
        StateDirectoryMode = "0700";
        ExecStartPre = [
          "${pkgs.coreutils}/bin/touch ${sessionFile}"
          (
            "${pkgs.bash}/bin/bash -c '"
            + "if [ ! -s ${secretFile} ]; then "
            + "umask 077; "
            + "${pkgs.coreutils}/bin/head -c 32 /dev/urandom "
            + "| ${pkgs.coreutils}/bin/base64 | ${pkgs.coreutils}/bin/tr -d \"\\n\" > ${secretFile}; "
            + "${pkgs.coreutils}/bin/chmod 600 ${secretFile}; fi'"
          )
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.defaultDownloadDir}"
        ];
        ExecStart =
          "${pkgs.bash}/bin/bash -c '"
          + "exec ${pkgs.aria2}/bin/aria2c --conf-path=${aria2Conf} "
          + "--rpc-secret=\"$(${pkgs.coreutils}/bin/cat ${secretFile})\"'";
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
        WorkingDirectory = globalCfg.homeDir;
      };
      wantedBy = [ "multi-user.target" ];
    };

    systemd.services.bromserver = {
      enable = true;
      description = "brom Web Server";
      after = [ "brom-aria2.service" ];
      wants = [ "brom-aria2.service" ];
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        StateDirectory = "brom";
        StateDirectoryMode = "0700";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}";
        ExecStart =
          "${cfg.package}/bin/brom"
          + " --port ${builtins.toString cfg.port}"
          + " --subdomain ${cfg.subdomain}"
          + " --data-dir ${cfg.dataDir}"
          + " --aria2-url http://127.0.0.1:${builtins.toString cfg.aria2RpcPort}/jsonrpc"
          + " --aria2-secret-file ${secretFile}";
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
        WorkingDirectory = globalCfg.homeDir;
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."${cfg.subdomain}/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}${cfg.subdomain}/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_read_timeout 300s;
          proxy_connect_timeout 10s;
        '';
      };
    };
  };
}
