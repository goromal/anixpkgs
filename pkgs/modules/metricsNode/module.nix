{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.metricsNode;
in {
  options.services.metricsNode = {
    enable = lib.mkEnableOption "enable metrics node services";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether to open the specific firewall port for inter-computer usage";
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts =
      lib.mkIf cfg.openFirewall [ service-ports.grafana.public ];

    services.vector = {
      enable = true;
      journaldAccess = true;
      settings = {
        sources = {
          vector_metrics = {
            # https://vector.dev/docs/reference/configuration/sources/internal_metrics/
            type = "internal_metrics";
          };
          os_metrics = {
            # https://vector.dev/docs/reference/configuration/sources/host_metrics/
            type = "host_metrics";
            collectors =
              [ "cgroups" "cpu" "disk" "filesystem" "load" "memory" "network" ];
            cgroups = { base = ""; };
          };
          statsd_metrics = {
            # https://vector.dev/docs/reference/configuration/sources/statsd/
            type = "statsd";
            address = "0.0.0.0:${builtins.toString service-ports.statsd}";
            mode = "udp";
          };
        };
        sinks = {
          prometheus = {
            # https://vector.dev/docs/reference/configuration/sinks/prometheus_exporter/
            type = "prometheus_exporter";
            # inputs = [ "vector_metrics" "os_metrics" "statsd_metrics" ];
            inputs = [ "statsd_metrics" ];
            address =
              "[::]:${builtins.toString service-ports.prometheus.input}";
          }; # ^^^^ TODO flush_period_secs,
        };
      };
    };
    # Check health with
    # curl -s http://localhost:9001/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, lastScrape, health, lastError}'
    services.prometheus = {
      enable = true;
      port = service-ports.prometheus.output;
      retentionTime = "15d";
      scrapeConfigs = [{
        job_name = "vector";
        static_configs = [{
          targets =
            [ "0.0.0.0:${builtins.toString service-ports.prometheus.input}" ];
        }];
      }];
    };
    services.grafana = { # ^^^^ TODO add plots configs
      enable = true;
      settings = {
        server = {
          domain = "grafana.metrics";
          http_port = service-ports.grafana.internal;
          http_addr = "127.0.0.1";
        };
        security = {
    allow_embedding = true; # Allows Grafana panels to be embedded in iframes
    cookie_samesite = "none"; # Ensures session cookies work across different origins
  };
  "auth.anonymous" = {
    enabled = true; # Enable anonymous access (optional, if required)
  };
  "http" = {
    enable_cors = true;  # Enable CORS
    cors_allow_origins = ["*"]; # Allow all origins (or specify your frontend domain)
  };
      };
    };
    services.nginx.virtualHosts.${config.services.grafana.settings.server.domain} =
      {
        listen = [{
          addr = "0.0.0.0";
          port = service-ports.grafana.public;
        }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${
              toString config.services.grafana.settings.server.http_port
            }";
          proxyWebsockets = true;
        };
      };
  };

  # Enable metrics emissions
  # ^^^^ https://statsd.readthedocs.io/en/stable/
}
