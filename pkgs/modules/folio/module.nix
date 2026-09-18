{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.folio-backend;

  agents = config.machines.features.agents.frameworks;
  agentAlternation = lib.concatStringsSep "|" agents;
  companion = cfg.agentCompanion && agents != [ ];

  # Same llm-agents CLIs the claude/codex agent components install (home.packages),
  # but placed on the backend service PATH so a spawned `exec claude`/`codex` in a
  # plain temp dir resolves. procps/coreutils/git cover common agent shell-outs.
  agentPackages = {
    claude = anixpkgs.flakeInputs.llm-agents.packages.${pkgs.system}.claude-code;
    codex = anixpkgs.flakeInputs.llm-agents.packages.${pkgs.system}.codex;
  };
  companionPath = [
    pkgs.tmux
    pkgs.procps
    pkgs.coreutils
    pkgs.gitMinimal
  ]
  ++ map (agent: agentPackages.${agent}) agents;

  folioTmuxConf = pkgs.writeText "folio-agent-tmux.conf" ''
    set -g mouse on
    set -g history-limit 50000
    # Smooth one-line scrolling in copy-mode (mirrors agent-ui): a finger-drag in
    # the companion terminal pages scrollback line by line, not a screen at a time.
    bind -T copy-mode    Up   send-keys -X scroll-up
    bind -T copy-mode    Down send-keys -X scroll-down
    bind -T copy-mode-vi Up   send-keys -X scroll-up
    bind -T copy-mode-vi Down send-keys -X scroll-down
  '';

  folioAgentSession = pkgs.writeShellApplication {
    name = "folio-agent-session";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      if [ "$#" -ne 2 ]; then
        echo "usage: folio-agent-session WORKDIR AGENT" >&2
        exit 2
      fi
      case "$2" in
        ${agentAlternation}) ;;
        *) echo "folio-agent-session: unsupported agent" >&2; exit 2 ;;
      esac
      # Pre-accept Claude Code's workspace-trust dialog so a headless companion
      # launch does not stall on it. Trust the stable spool parent (not each
      # ephemeral session dir): claude honors an ancestor's trust, so every
      # session under the spool inherits it without accumulating stale
      # ~/.claude.json entries. Idempotent, flock-guarded.
      if [ "$2" = claude ]; then
        spool="$(dirname "$1")"
        cfg="$HOME/.claude.json"
        (
          flock 9
          tmp="$(mktemp "$HOME/.claude.json.folio.XXXXXX")"
          if [ -f "$cfg" ]; then base="$cfg"; else base="$tmp"; printf '{}' >"$base"; fi
          if jq --arg d "$spool" '.projects[$d].hasTrustDialogAccepted = true' "$base" >"$tmp.out"; then
            mv "$tmp.out" "$cfg"
          fi
          rm -f "$tmp" "$tmp.out"
        ) 9>"$HOME/.claude.json.folio.lock" || true
      fi
      cd "$1"
      exec "$2"
    '';
  };

  folioAgentAttach = pkgs.writeShellApplication {
    name = "folio-agent-attach";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
    ];
    text = ''
      if [ "$#" -ne 1 ] || [[ ! "$1" =~ ^folio-agent--(${agentAlternation})--[0-9a-f]{8}$ ]]; then
        echo "folio-agent-attach: invalid session" >&2
        exit 2
      fi
      # When the session is gone (agent exited), hold the pane with a notice
      # instead of exiting, so ttyd doesn't silently reconnect-loop.
      hold() {
        printf '\r\n\033[1;33mSession ended.\033[0m Close this panel or start a new session.\r\n'
        sleep infinity
      }
      if ! tmux -L folio-agent has-session -t "$1" 2>/dev/null; then
        hold
      fi
      tmux -L folio-agent attach-session -t "$1" || true
      if ! tmux -L folio-agent has-session -t "$1" 2>/dev/null; then
        hold
      fi
    '';
  };
in
{
  options.services.folio-backend = {
    enable = mkEnableOption "folio Book Study Companion backend";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/folio";
      description = "Directory holding the folio SQLite database.";
    };

    desktop = mkEnableOption "folio Electron desktop shell + Gnome launcher";

    isHub = mkEnableOption "folio hub role (ground-truth DB + lock server)";

    hubHost = mkOption {
      type = types.str;
      default = "";
      description = "For spokes: the hub's mDNS host (e.g. \"ats.local\"), resolved via wormhole.";
    };

    agentCompanion = mkEnableOption "folio agent companion (temp-dir agent terminals)";

    agentSecretsFile = mkOption {
      type = types.str;
      default = "${globalCfg.homeDir}/secrets/flask/folio_agent.json";
      description = "Secrets file for the companion; provisioned as a copy of agent_ui.json.";
    };

    agentSpoolDir = mkOption {
      type = types.str;
      default = "/tmp/folio-agent";
      description = "Base directory holding ephemeral agent session working dirs.";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 andrew dev -"
      "z ${cfg.dataDir}/folio.db 0640 andrew dev -"
    ];

    assertions = [
      {
        assertion = !companion || config.services.agent_ui.enable;
        message = "folio agentCompanion needs services.agent_ui.enable (shared secrets source).";
      }
    ];

    systemd.services.folio-backend = {
      description = "folio backend (FastAPI)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      path = lib.optionals companion companionPath;

      serviceConfig = {
        Type = "simple";
        User = "andrew";
        Group = "dev";
        # Run as root (the "+" prefix) to (re)claim ownership of the data dir and
        # DB before the andrew-owned service opens it. Makes the migration off the
        # old dedicated "folio" user robust: a pre-existing folio.db keeps the old
        # (now-removed) owner, which tmpfiles "z" does not reliably re-chown.
        ExecStartPre = [
          "+${pkgs.coreutils}/bin/chown -R andrew:dev ${cfg.dataDir}"
        ]
        ++ lib.optional companion (
          "+${pkgs.coreutils}/bin/install -o andrew -g dev -m0600 "
          + "${config.services.agent_ui.secretsFile} ${cfg.agentSecretsFile}"
        );
        ExecStart = "${anixpkgs.folio-backend}/bin/folio-backend";
        WorkingDirectory = cfg.dataDir;
        Restart = "on-failure";
        RestartSec = "5s";
        # Companion tmux sessions run on a `-L folio-agent` server spawned by this
        # unit; kill only the main process on stop so a restart/redeploy leaves
        # those sessions alive ("persist until closed").
        KillMode = "process";
        Environment = [
          "HOME=${globalCfg.homeDir}"
          "FOLIO_DB=${cfg.dataDir}/folio.db"
          "FOLIO_HOST=127.0.0.1"
          "FOLIO_PORT=${toString service-ports.folio.internal}"
          "FOLIO_STATIC_DIR=${anixpkgs.folio-frontend}"
          "FOLIO_MACHINE=${config.networking.hostName}"
          "FOLIO_IS_HUB=${if cfg.isHub then "true" else "false"}"
          "FOLIO_HUB_HOST=${cfg.hubHost}"
          "FOLIO_HUB_PORT=${toString service-ports.folio.public}"
        ]
        ++ lib.optionals companion [
          "FOLIO_AGENTS=${lib.concatStringsSep " " agents}"
          "FOLIO_AGENT_SECRETS=${cfg.agentSecretsFile}"
          "FOLIO_AGENT_SPOOL=${cfg.agentSpoolDir}"
          "FOLIO_AGENT_TMUX=${pkgs.tmux}/bin/tmux"
          "FOLIO_AGENT_TMUX_CONFIG=${folioTmuxConf}"
          "FOLIO_AGENT_SESSION_CMD=${folioAgentSession}/bin/folio-agent-session"
        ];
      };
    };

    systemd.services.folio-agent-terminal = lib.mkIf companion {
      description = "folio agent companion ttyd";
      after = [ "folio-backend.service" ];
      wants = [ "folio-backend.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ pkgs.tmux ];
      environment.HOME = globalCfg.homeDir;
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ttyd}/bin/ttyd --port ${toString service-ports.folio.agentTerminal} --interface 127.0.0.1 --writable --url-arg --check-origin --auth-header X-Folio-Agent-Authenticated --base-path /folio/agent/terminal ${folioAgentAttach}/bin/folio-agent-attach";
        Restart = "always";
        RestartSec = 3;
        User = "andrew";
        Group = "dev";
        UMask = "0077";
      };
    };

    # ---- web: nginx serves folio (SPA at /folio + API) on the dedicated public
    # port; the backend itself binds localhost only. Mirrors the vikunja pattern. ----
    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local:${toString service-ports.folio.public}" =
      {
        onlySSL = true;
        sslCertificateKey = "${globalCfg.homeDir}/secrets/vpn/key.pem";
        sslCertificate = "${globalCfg.homeDir}/secrets/vpn/chain.pem";
        extraConfig = ''
          client_max_body_size 512m;
        '';
        listen = [
          {
            addr = "0.0.0.0";
            port = service-ports.folio.public;
            ssl = true;
          }
        ];
        # Port root -> the SPA. The landing page's dedicated-port card sends the browser
        # to https://<current-host>:6667/ ; redirect that to the SPA at /folio/.
        locations."= /" = {
          return = "302 /folio/";
        };
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString service-ports.folio.internal}";
          proxyWebsockets = true;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
        # SSE (agent view-follow F + live sync G) must not be buffered.
        locations."/view/stream" = {
          proxyPass = "http://127.0.0.1:${toString service-ports.folio.internal}";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 3600s;
          '';
        };
        locations."= /folio/agent/auth-check" = lib.mkIf companion {
          proxyPass = "http://127.0.0.1:${toString service-ports.folio.internal}/agent/auth-check";
          extraConfig = ''
            internal;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
          '';
        };
        locations."/folio/agent/terminal/" = lib.mkIf companion {
          proxyPass = "http://127.0.0.1:${toString service-ports.folio.agentTerminal}";
          proxyWebsockets = true;
          extraConfig = ''
            auth_request /folio/agent/auth-check;
            proxy_set_header X-Folio-Agent-Authenticated yes;
            proxy_set_header Host $host;
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
          '';
        };
      };
    # Dedicated public port is registered structurally for the landing page.
    machines.base.webServices = [
      {
        name = "folio";
        tag = "Aspiration";
        path = "#";
        port = service-ports.folio.public;
        description = "Book Study Companion (port ${toString service-ports.folio.public})";
        icon = "book-open";
      }
    ];

    networking.firewall.allowedTCPPorts = [ service-ports.folio.public ];

    environment.systemPackages = mkIf cfg.desktop [ anixpkgs.folio-desktop ];

    services.folio-mcp.enable = mkDefault (!cfg.isHub);
  };
}
