{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.assistant_ui;
  agents = config.machines.features.agents.frameworks;

  companion = import ../../../nixos/agent-companion.nix { inherit pkgs lib; } {
    name = "assistant";
    inherit agents;
    skill = "assistant";
    appLabel = "the Assistant (second-brain) console";
    skillScope = "all ITAR and second-brain work";
    terminalPort = service-ports.assistant_ui_agent_terminal;
    terminalBasePath = "/assistant/agent/terminal";
    authHeader = "X-Assistant-Agent-Authenticated";
    backendService = "assistant_ui";
    homeDir = globalCfg.homeDir;
    workRepo = cfg.repo;
    # nginx forwards Host without a port, so the browser Origin only matches it on
    # the default HTTPS port; elsewhere ttyd would refuse every websocket.
    checkOrigin = config.machines.base.webServerSecurePort == 443;
  };
in
{
  options.services.assistant_ui = {
    enable = lib.mkEnableOption "Assistant UI (agent sessions rooted in the second-brain repo)";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The assistant_ui package to use";
      default = anixpkgs.assistant_ui;
    };
    repo = lib.mkOption {
      type = lib.types.str;
      default = "goromal/second-brain";
      description = "GitHub owner/name of the repo every session works in.";
    };
    repoDir = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/sources/second-brain";
      description = "Durable checkout of the repo, shared by all sessions (cloned on first session).";
    };
    agentSecretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/secrets/flask/assistant_agent.json";
      description = "Secrets file for the sessions API; provisioned as a copy of agent_ui.json.";
    };
    pathPkgs = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Extra packages on the agents' PATH";
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.agent_ui.enable;
        message = "assistant_ui needs services.agent_ui.enable (shared secrets source).";
      }
      {
        assertion = agents != [ ];
        message = "assistant_ui needs at least one machines.features.agents.frameworks entry.";
      }
    ];
    machines.agents.privateSkills = [ "assistant" ];

    # Also on interactive shells of the assistant host, for manual media intake.
    environment.systemPackages = [ anixpkgs.media2notes ];

    machines.base.webServices = [
      {
        name = "Assistant";
        tag = "Aspiration";
        path = "/assistant/";
        description = "ITAR assistant agents on second-brain";
        icon = "brain";
        faviconSvg = anixpkgs.pkgData.icons.favicons.brain.data;
      }
    ];

    systemd.services.assistant_ui = {
      enable = true;
      description = "Assistant UI";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          "${cfg.package}/bin/assistant_ui"
          "--subdomain /assistant"
          "--port ${builtins.toString service-ports.assistant_ui}"
          "--agents ${lib.concatStringsSep "," agents}"
          "--agent-secrets ${cfg.agentSecretsFile}"
          "--repo-dir ${cfg.repoDir}"
          "--agent-tmux ${pkgs.tmux}/bin/tmux"
          "--agent-tmux-config ${companion.tmuxConf}"
          "--agent-session-cmd ${companion.sessionCommand}"
          "--git ${pkgs.git}/bin/git"
        ];
        ExecStartPre =
          "+${pkgs.coreutils}/bin/install -o andrew -g dev -m0600 "
          + "${config.services.agent_ui.secretsFile} ${cfg.agentSecretsFile}";
        # Agent tmux sessions run on a `-L assistant-agent` server spawned by this
        # unit; kill only the main process so a redeploy leaves them alive.
        KillMode = "process";
        Environment = [ "HOME=${globalCfg.homeDir}" ];
        ReadWritePaths = [
          "/"
          "${globalCfg.homeDir}"
        ];
        WorkingDirectory = globalCfg.homeDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
      # Full git (+ssh) ahead of the companion's git-minimal, then what the
      # assistant skill shells out to: gh, rg, sqlite3 (Tactical, read-only),
      # python3 (tools/sb), task-tools (Google Tasks), wiki-tools, media2notes
      # (media intake: URL -> transcript + frames).
      path = [
        pkgs.git
        pkgs.openssh
        pkgs.gh
        pkgs.ripgrep
        pkgs.sqlite
        pkgs.python3
        pkgs.jq
        pkgs.curl
        pkgs.diffutils
        anixpkgs.task-tools
        anixpkgs.wiki-tools
        anixpkgs.media2notes
      ]
      ++ cfg.pathPkgs
      ++ companion.servicePath;
    };

    systemd.services.assistant-agent-terminal = companion.terminalService;

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/assistant/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.assistant_ui}/assistant/";
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
      locations."= /assistant/agent/_auth" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.assistant_ui}/assistant/agent/auth-check";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
        '';
      };
      locations."/assistant/agent/terminal/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.assistant_ui_agent_terminal}";
        proxyWebsockets = true;
        extraConfig = ''
          auth_request /assistant/agent/_auth;
          proxy_set_header X-Assistant-Agent-Authenticated yes;
          proxy_set_header Host $host;
          proxy_read_timeout 86400;
          proxy_send_timeout 86400;
        '';
      };
    };
  };
}
