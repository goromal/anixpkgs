{
  pkgs,
  config,
  lib,
  ...
}:
let
  service-ports = import ../../service-ports.nix;
  cfg = config.services.comfyui;
  extendedPkgs = pkgs.extend (import ../../../../overlay.nix);
in
{
  options.services.comfyui = {
    enable = lib.mkEnableOption "ComfyUI Stable Diffusion server";
    port = lib.mkOption {
      type = lib.types.port;
      default = service-ports.comfyui;
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/data/andrew/comfyui";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = extendedPkgs.comfyui;
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.runWebServer = true;

    machines.base.webServices = [
      {
        name = "ComfyUI";
        path = "/comfyui/";
        description = "Stable Diffusion (SDXL) image generation";
        icon = "film";
      }
    ];

    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/comfyui/" = {
        extraConfig = ''
          set $comfyui_fwd $request_uri;
          if ($comfyui_fwd ~ ^/comfyui(/.*)$) {
            set $comfyui_fwd $1;
          }
          proxy_pass http://127.0.0.1:${builtins.toString cfg.port}$comfyui_fwd;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection $connection_upgrade;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 andrew dev -"
      "d ${cfg.dataDir}/models 0755 andrew dev -"
      "d ${cfg.dataDir}/input 0755 andrew dev -"
      "d ${cfg.dataDir}/output 0755 andrew dev -"
      "d ${cfg.dataDir}/custom_nodes 0755 andrew dev -"
    ];

    systemd.services.comfyui = {
      enable = true;
      description = "ComfyUI Stable Diffusion Server";
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/comfyui --listen 127.0.0.1 --port ${builtins.toString cfg.port} --base-directory ${cfg.dataDir} --database-url sqlite:///${cfg.dataDir}/user/comfyui.db --lowvram";
        ReadWritePaths = [
          cfg.dataDir
          "/tmp"
        ];
        WorkingDirectory = cfg.dataDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
        Environment = [
          "HOME=/data/andrew"
        ];
      };
      wantedBy = [ "multi-user.target" ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
