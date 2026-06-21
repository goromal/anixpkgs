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
  vramFlag = if cfg.vramMode == "auto" then "" else "--${cfg.vramMode}";
in
{
  options.services.comfyui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.machines.cudaNode.enable;
      description = "ComfyUI Stable Diffusion server (defaults on for GPU/cudaNode machines)";
    };
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
    vramMode = lib.mkOption {
      type = lib.types.enum [
        "lowvram"
        "normalvram"
        "highvram"
        "novram"
        "auto"
      ];
      default = "lowvram";
      description = "ComfyUI VRAM strategy; 'auto' lets ComfyUI decide (no flag).";
    };
    cozy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run the cozy image-generation UI alongside ComfyUI";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = extendedPkgs.cozy;
      };
      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/data/andrew/cozy";
      };
      workflowDir = lib.mkOption {
        type = lib.types.str;
        default = cfg.dataDir;
        description = "Directory holding <name>.api.json workflow files";
      };
      workflows = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = if config.machines.base.machineType == "jetson" then [
          "imggen-quantized"
        ] else [
          "imggen"
          "imggen2"
        ];
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
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
              client_max_body_size 100m;
              set $comfyui_path $request_uri;
              set $comfyui_query "";
              if ($comfyui_path ~ "^/comfyui(/[^?]*)\?(.*)$") {
                set $comfyui_path $1;
                set $comfyui_query $2;
              }
              if ($comfyui_path ~ "^/comfyui(/[^?]*)$") {
                set $comfyui_path $1;
              }
              proxy_pass http://127.0.0.1:${builtins.toString cfg.port}$comfyui_path?$comfyui_query;
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
            ExecStart = "${cfg.package}/bin/comfyui --listen 127.0.0.1 --port ${builtins.toString cfg.port} --base-directory ${cfg.dataDir} --database-url sqlite:///${cfg.dataDir}/user/comfyui.db ${vramFlag}";
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
      }
      (lib.mkIf cfg.cozy.enable {
        machines.base.webServices = [
          {
            name = "cozy";
            path = "/cozy/";
            description = "ComfyUI image generation";
            icon = "tv";
            faviconSvg = ../../../python-packages/flasks/cozy/tv.svg;
          }
        ];
        systemd.tmpfiles.rules = [
          "d ${cfg.cozy.stateDir} 0755 andrew dev -"
        ];
        systemd.services.cozy = {
          enable = true;
          description = "cozy ComfyUI image-generation UI";
          after = [ "comfyui.service" ];
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            Type = "simple";
            ExecStart = "${cfg.cozy.package}/bin/cozy --port ${builtins.toString service-ports.cozy} --subdomain /cozy --comfyui-url http://127.0.0.1:${builtins.toString cfg.port} --state-dir ${cfg.cozy.stateDir} --workflow-dir ${cfg.cozy.workflowDir} --workflows ${lib.concatStringsSep "," cfg.cozy.workflows}";
            ReadWritePaths = [ cfg.cozy.stateDir ];
            WorkingDirectory = cfg.cozy.stateDir;
            Restart = "always";
            RestartSec = 5;
            User = "andrew";
            Group = "dev";
          };
          wantedBy = [ "multi-user.target" ];
        };
        services.nginx.virtualHosts."${config.networking.hostName}.local" = {
          locations."/cozy/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString service-ports.cozy}/cozy/";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_read_timeout 600;
              proxy_send_timeout 600;
            '';
          };
        };
      })
    ]
  );
}
