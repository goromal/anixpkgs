{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.budget_ui;

  agents = config.machines.features.agents.frameworks;
  companion = cfg.agentCompanion && agents != [ ];

  budgetCompanion = import ../../../nixos/agent-companion.nix { inherit pkgs lib; } {
    name = "budget";
    inherit agents;
    skill = "budget-usage";
    appLabel = "the budget app";
    terminalPort = service-ports.budget_ui_agent_terminal;
    terminalBasePath = "/budget/agent/terminal";
    authHeader = "X-Budget-Agent-Authenticated";
    backendService = "budget_ui";
    homeDir = globalCfg.homeDir;
    # Served on the default HTTPS port, so Origin and Host agree (unlike folio).
    checkOrigin = true;
  };
in
{
  options.services.budget_ui = {
    enable = lib.mkEnableOption "enable budget server";
    rootDir = lib.mkOption {
      type = lib.types.str;
      description = "Root directory for the server";
      default = "${globalCfg.homeDir}/data/budgets";
    };
    package = lib.mkOption {
      type = lib.types.package;
      description = "The budget_ui package to use";
      default = anixpkgs.budget_ui;
    };
    pathPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Packages to expose to the program's PATH";
      default = [ ];
    };
    agentCompanion = lib.mkEnableOption "budget agent companion (temp-dir agent terminals)";
    agentSecretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/secrets/flask/budget_agent.json";
      description = "Secrets file for the companion; provisioned as a copy of agent_ui.json.";
    };
    agentSpoolDir = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/budget-agent";
      description = "Base directory holding ephemeral agent session working dirs.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !companion || config.services.agent_ui.enable;
        message = "budget_ui agentCompanion needs services.agent_ui.enable (shared secrets source).";
      }
    ];
    machines.agents.privateSkills = lib.mkIf companion [ "budget-usage" ];

    # Register Budget UI in the web services landing page
    machines.base.webServices = [
      {
        name = "Budget";
        tag = "Utilities";
        path = "/budget/";
        description = "Budget tracking";
        icon = "piggy-bank";
        faviconSvg = anixpkgs.pkgData.icons.favicons."piggy-bank".data;
      }
    ];

    systemd.services.budget_ui = {
      enable = true;
      description = "Budget UI";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart =
          "${cfg.package}/bin/budget_ui --subdomain /budget --port ${builtins.toString service-ports.budget_ui}"
          + lib.optionalString companion (
            " --agents ${lib.concatStringsSep "," agents}"
            + " --agent-secrets ${cfg.agentSecretsFile}"
            + " --agent-spool ${cfg.agentSpoolDir}"
            + " --agent-tmux ${pkgs.tmux}/bin/tmux"
            + " --agent-tmux-config ${budgetCompanion.tmuxConf}"
            + " --agent-session-cmd ${budgetCompanion.sessionCommand}"
          );
        ExecStartPre = lib.optional companion (
          "+${pkgs.coreutils}/bin/install -o andrew -g dev -m0600 "
          + "${config.services.agent_ui.secretsFile} ${cfg.agentSecretsFile}"
        );
        # Companion tmux sessions run on a `-L budget-agent` server spawned by this
        # unit; kill only the main process so a redeploy leaves them alive.
        KillMode = "process";
        Environment = [ "HOME=${globalCfg.homeDir}" ];
        ReadWritePaths = [
          "/"
          "${cfg.rootDir}"
          "${globalCfg.homeDir}"
        ];
        WorkingDirectory = cfg.rootDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      path = cfg.pathPkgs ++ lib.optionals companion budgetCompanion.servicePath;
    };

    systemd.services.budget-agent-terminal = lib.mkIf companion budgetCompanion.terminalService;

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/budget/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.budget_ui}/budget/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
      # Internal-only twin of the public auth-check route: auth_request needs a
      # location the browser can't hit directly.
      locations."= /budget/agent/_auth" = lib.mkIf companion {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.budget_ui}/budget/agent/auth-check";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
      locations."/budget/agent/terminal/" = lib.mkIf companion {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.budget_ui_agent_terminal}";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request /budget/agent/_auth;
          proxy_set_header X-Budget-Agent-Authenticated yes;
          proxy_set_header Host $host;
          proxy_read_timeout 86400;
          proxy_send_timeout 86400;
        '';
      };
    };
  };
}
