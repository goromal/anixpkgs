{
  pkgs,
  lib,
  config,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  cfg = config.services.agent_ui;
  globalCfg = config.machines.base;
  agents = builtins.filter (
    agent:
    lib.elem agent [
      "claude"
      "codex"
    ]
  ) globalCfg.agentFrameworks;
  agentArgs = lib.concatMapStringsSep " " (agent: "--agent ${lib.escapeShellArg agent}") agents;

  agentEnter = pkgs.writeShellApplication {
    name = "agent-ui-enter";
    text = ''
      case "''${AGENT_UI_AGENT:-}" in
        claude|codex) ;;
        *) echo "agent-ui-enter: unsupported agent" >&2; exit 2 ;;
      esac

      cd "$DEVSHELL_ROOT/sources"
      exec "$AGENT_UI_AGENT"
    '';
  };

  agentSession = pkgs.writeShellApplication {
    name = "agent-ui-session";
    runtimeInputs = [
      anixpkgs.devshell
      pkgs.direnv
      agentEnter
    ];
    text = ''
      if [ "$#" -ne 2 ]; then
        echo "usage: agent-ui-session WORKSPACE AGENT" >&2
        exit 2
      fi

      case "$2" in
        claude|codex) ;;
        *) echo "agent-ui-session: unsupported agent" >&2; exit 2 ;;
      esac

      export AGENT_UI_AGENT="$2"
      # shellcheck disable=SC2016 # Expanded by the devshell's inner shell.
      exec devshell "$1" --run 'exec direnv exec "$DEVSHELL_ROOT" ${agentEnter}/bin/agent-ui-enter'
    '';
  };

  agentAttach = pkgs.writeShellApplication {
    name = "agent-ui-attach";
    runtimeInputs = [ pkgs.tmux ];
    text = ''
      if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^agent-ui-[A-Za-z0-9_-]+--(claude|codex)--[0-9a-f]{8}$ ]]; then
        echo "agent-ui-attach: invalid session" >&2
        exit 2
      fi
      exec tmux attach-session -t "$1"
    '';
  };

  tokenCommand = pkgs.writeShellApplication {
    name = "agent-ui-token";
    text = ''
      token_file=/var/lib/agent-ui/token
      if [ ! -r "$token_file" ]; then
        echo "agent-ui-token: token is not available" >&2
        exit 1
      fi
      cat "$token_file"
    '';
  };
in
{
  options.services.agent_ui = {
    enable = lib.mkEnableOption "workspace agent terminal UI";
    package = lib.mkOption {
      type = lib.types.package;
      default = anixpkgs.agent_ui;
      description = "The agent UI package to run.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = service-ports.agent_ui.web;
      description = "Loopback port for the workspace chooser.";
    };
    terminalPort = lib.mkOption {
      type = lib.types.port;
      default = service-ports.agent_ui.terminal;
      description = "Loopback port for ttyd.";
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      default = "/agents";
      description = "Path prefix exposed through nginx.";
    };
    devrc = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/.devrc";
      description = "Workspace configuration file.";
    };
  };

  config = lib.mkIf (cfg.enable && agents != [ ]) {
    environment.systemPackages = [ tokenCommand ];

    machines.base.webServices = [
      {
        name = "Agent Terminal";
        tag = "Aspiration";
        path = "${cfg.subdomain}/";
        description = "Claude and Codex workspace terminals";
        icon = "gears";
        faviconSvg = anixpkgs.pkgData.icons.favicons.gears.data;
      }
    ];

    systemd.services.agent-ui = {
      description = "Workspace Agent Terminal UI";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.tmux ];
      environment.HOME = globalCfg.homeDir;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/agent-ui --port ${toString cfg.port} --subdomain ${cfg.subdomain} --devrc ${cfg.devrc} --token-file /var/lib/agent-ui/token --tmux-bin ${pkgs.tmux}/bin/tmux --session-command ${agentSession}/bin/agent-ui-session ${agentArgs}";
        Restart = "always";
        RestartSec = 3;
        User = "andrew";
        Group = "dev";
        StateDirectory = "agent-ui";
        UMask = "0077";
      };
    };

    systemd.services.agent-ui-terminal = {
      description = "Workspace Agent Terminal ttyd";
      after = [ "agent-ui.service" ];
      wants = [ "agent-ui.service" ];
      wantedBy = [ "multi-user.target" ];
      environment.HOME = globalCfg.homeDir;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ttyd}/bin/ttyd --port ${toString cfg.terminalPort} --interface 127.0.0.1 --writable --url-arg --check-origin --auth-header X-Agent-Ui-Authenticated --base-path ${cfg.subdomain}/terminal ${agentAttach}/bin/agent-ui-attach";
        Restart = "always";
        RestartSec = 3;
        User = "andrew";
        Group = "dev";
        UMask = "0077";
      };
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."= ${cfg.subdomain}/auth-check" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}${cfg.subdomain}/auth-check";
        extraConfig = ''
          internal;
          proxy_pass_request_body off;
          proxy_set_header Content-Length "";
          proxy_set_header Connection "";
          proxy_set_header Upgrade "";
        '';
      };
      locations."${cfg.subdomain}/terminal/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.terminalPort}";
        proxyWebsockets = true;
        extraConfig = ''
          if ($scheme = http) { return 301 https://$host$request_uri; }
          auth_request ${cfg.subdomain}/auth-check;
          proxy_set_header X-Agent-Ui-Authenticated yes;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_read_timeout 86400;
          proxy_send_timeout 86400;
        '';
      };
      locations."${cfg.subdomain}/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.port}${cfg.subdomain}/";
        proxyWebsockets = true;
        extraConfig = ''
          if ($scheme = http) { return 301 https://$host$request_uri; }
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
