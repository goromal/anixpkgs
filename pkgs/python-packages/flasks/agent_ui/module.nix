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
  agents = config.machines.features.agents.frameworks;
  agentAlternation = lib.concatStringsSep "|" (agents ++ [ "shell" ]);
  agentArgs = lib.concatMapStringsSep " " (agent: "--agent ${lib.escapeShellArg agent}") agents;

  # The configured agent CLIs (same llm-agents packages the agent components
  # install into the user profile) must be on the service PATH: the dedicated
  # `-L agent-ui` tmux server inherits this service's env, and `agent-ui-enter`
  # exec's the agent by name inside it. Without this a session dies with
  # "exec: claude: not found". procps/coreutils/git cover common agent shell-outs.
  agentPackages = {
    claude = anixpkgs.flakeInputs.llm-agents.packages.${pkgs.system}.claude-code;
    codex = anixpkgs.flakeInputs.llm-agents.packages.${pkgs.system}.codex;
  };
  agentSessionPath = [
    pkgs.tmux
    pkgs.procps
    pkgs.coreutils
    pkgs.gitMinimal
  ]
  ++ map (agent: agentPackages.${agent}) agents;

  agentTmuxConf = pkgs.writeText "agent-ui-tmux.conf" ''
    set -g mouse on
    set -g history-limit 50000
    # Smooth one-line scrolling in copy-mode: bind Up/Down to scroll-up/down
    # (no cursor-first lag), so a finger-drag from the web terminal pages the
    # scrollback line by line rather than a full screen at a time.
    bind -T copy-mode    Up   send-keys -X scroll-up
    bind -T copy-mode    Down send-keys -X scroll-down
    bind -T copy-mode-vi Up   send-keys -X scroll-up
    bind -T copy-mode-vi Down send-keys -X scroll-down
  '';

  agentEnter = pkgs.writeShellApplication {
    name = "agent-ui-enter";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
      pkgs.util-linux
    ];
    text = ''
      case "''${AGENT_UI_AGENT:-}" in
        ${agentAlternation}) ;;
        *) echo "agent-ui-enter: unsupported agent" >&2; exit 2 ;;
      esac

      cd "$DEVSHELL_ROOT/sources"
      if [ "$AGENT_UI_AGENT" = shell ]; then
        exec ${pkgs.bashInteractive}/bin/bash -i
      fi
      # Pre-accept Claude Code's workspace-trust dialog for this workspace so a
      # headless agent-ui launch does not stall on it -- its default "No, exit"
      # would otherwise be selected and kill the session. Idempotent, and locked
      # so concurrent session launches don't clobber ~/.claude.json.
      if [ "$AGENT_UI_AGENT" = claude ]; then
        cfg="$HOME/.claude.json"
        (
          flock 9
          tmp="$(mktemp "$HOME/.claude.json.agentui.XXXXXX")"
          if [ -f "$cfg" ]; then base="$cfg"; else base="$tmp"; printf '{}' >"$base"; fi
          if jq --arg d "$PWD" '.projects[$d].hasTrustDialogAccepted = true' "$base" >"$tmp.out"; then
            mv "$tmp.out" "$cfg"
          fi
          rm -f "$tmp" "$tmp.out"
        ) 9>"$HOME/.claude.json.agentui.lock" || true
      fi
      exec "$AGENT_UI_AGENT"
    '';
  };

  agentSession = pkgs.writeShellApplication {
    name = "agent-ui-session";
    runtimeInputs = [
      anixpkgs.devshell
      pkgs.direnv
      pkgs.lorri
      agentEnter
    ];
    text = ''
      if [ "$#" -ne 2 ]; then
        echo "usage: agent-ui-session WORKSPACE AGENT" >&2
        exit 2
      fi

      case "$2" in
        ${agentAlternation}) ;;
        *) echo "agent-ui-session: unsupported agent" >&2; exit 2 ;;
      esac

      export AGENT_UI_AGENT="$2"
      # shellcheck disable=SC2016 # Expanded by the devshell's inner shell.
      exec devshell "$1" --run 'exec direnv exec "$DEVSHELL_ROOT" ${agentEnter}/bin/agent-ui-enter'
    '';
  };

  agentAttach = pkgs.writeShellApplication {
    name = "agent-ui-attach";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
    ];
    text = ''
      if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^agent-ui-[A-Za-z0-9_-]+--(${agentAlternation})--[0-9a-f]{8}$ ]]; then
        echo "agent-ui-attach: invalid session" >&2
        exit 2
      fi
      # When the session is gone (agent exited), don't exit -- that makes ttyd
      # silently reconnect-loop. Show a clear notice and hold the pane open so the
      # message stays until the user closes the tab or navigates away.
      hold() {
        printf '\r\n\033[1;33mSession ended.\033[0m Close this tab or return to the Agents list.\r\n'
        sleep infinity
      }
      if ! tmux -L agent-ui has-session -t "$1" 2>/dev/null; then
        hold
      fi
      tmux -L agent-ui attach-session -t "$1" || true
      if ! tmux -L agent-ui has-session -t "$1" 2>/dev/null; then
        hold
      fi
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
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "${globalCfg.homeDir}/secrets/flask/agent_ui.json";
      description = "Path to JSON file with secret_key and password_hash.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = agents != [ ];
        message = "Agent UI requires at least one machines.features.agents.frameworks entry.";
      }
    ];
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
      path = agentSessionPath;
      environment.HOME = globalCfg.homeDir;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/agent-ui --port ${toString cfg.port} --subdomain ${cfg.subdomain} --devrc ${cfg.devrc} --history ${globalCfg.homeDir}/.devhist --secrets-file ${cfg.secretsFile} --tmux-bin ${pkgs.tmux}/bin/tmux --tmux-socket agent-ui --tmux-config ${agentTmuxConf} --session-command ${agentSession}/bin/agent-ui-session --workspace-command ${anixpkgs.devshell}/bin/devshellctl ${agentArgs}";
        Restart = "always";
        RestartSec = 3;
        User = "andrew";
        Group = "dev";
        UMask = "0077";
        # The dedicated `-L agent-ui` tmux server is spawned by the first session
        # and lives in this unit's cgroup. Kill only the main process on stop so a
        # restart/redeploy leaves the tmux server (and its sessions) running.
        KillMode = "process";
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
