{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.chat_ui;
in
{
  options.services.chat_ui = {
    enable = lib.mkEnableOption "chat UI for the local Ollama models";
    package = lib.mkOption {
      type = lib.types.package;
      default = anixpkgs.chat_ui;
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = service-ports.chat_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "/chat";
    };
    ollamaUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:11434";
      description = "Loopback Ollama API (machines.localLlm's).";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Model preselected in the dropdown (machines.localLlm.model).";
    };
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/secrets/flask/chat_ui.json";
      description = "JSON file with username, secret_key and password_hash.";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Chat";
        tag = "Content";
        path = "${cfg.subdomain}/";
        description = "Chat with the local LLMs";
        icon = "comment-dots";
        faviconSvg = anixpkgs.pkgData.icons.favicons."comment-dots".data;
      }
    ];

    systemd.services.chat_ui = {
      enable = true;
      description = "Chat UI for the local Ollama models";
      after = [ "ollama.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/chat_ui --port ${toString cfg.port} --subdomain ${cfg.subdomain} --ollama-url ${cfg.ollamaUrl} --default-model '${cfg.defaultModel}' --secrets-file ${cfg.secretsFile}";
        WorkingDirectory = globalCfg.homeDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."${cfg.subdomain}/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}${cfg.subdomain}/";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffering off;
          proxy_read_timeout 900;
          client_max_body_size 4m;
        '';
      };
    };
  };
}
