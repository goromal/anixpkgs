{ pkgs, config, lib, ... }:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.metricsNode;
in {
  options.services.metricsNode = {
    enable = lib.mkEnableOption "enable metrics node services";
  };

  config = lib.mkIf cfg.enable {
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
          statsd = {
            # https://vector.dev/docs/reference/configuration/sources/statsd/
            type = "statsd";
            address = "0.0.0.0:${builtins.toString service-ports.statsd}";
            mode = "tcp";
          };
        };
        sinks = {
          prometheus = {
            # https://vector.dev/docs/reference/configuration/sinks/prometheus_exporter/
            type = "prometheus_exporter";
            inputs = [ "vector_metrics" "os_metrics" ];
            address = "[::]:${builtins.toString service-ports.prometheus.input}";
          };
        };
      };
    };
    services.prometheus = {
      enable = true;
      port = service-ports.prometheus.output;
      scrapeConfigs = [{
        job_name = "vector";
        static_configs = [{ targets = [ "127.0.0.1:${builtins.toString service-ports.prometheus.input}" ]; }];
      }];
    };
    services.grafana = { # ^^^^ TODO declarative configs w/ good descriptions
      enable = true;
      domain = "grafana.ajt";
      port = service-ports.grafana;
      addr = "127.0.0.1";
    };
    services.nginx.virtualHosts.${config.services.grafana.domain} = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString config.services.grafana.port}";
        proxyWebsockets = true;
      };
    };
  };
  # ^^^^ TODO set module options for e.g., orchestrator to emit metrics
  # ^^^^ https://statsd.readthedocs.io/en/stable/
}
