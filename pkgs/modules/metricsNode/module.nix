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
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      service-ports.grafana.internal
      service-ports.netdata
    ];

    services.netdata = {
      enable = true;
      config = {
        global = { "memory mode" = "ram"; };
        plugins = { "cgroup plugin" = "yes"; };
        web = {
          "bind to" = "tcp:0.0.0.0:${builtins.toString service-ports.netdata}";
        };
      };
    };

    services.vector = {
      enable = true;
      journaldAccess = true;
      settings = {
        sources = {
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
            inputs = [ "statsd_metrics" ];
            address =
              "[::]:${builtins.toString service-ports.prometheus.input}";
          };
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
    services.grafana = {
      enable = true;
      settings = {
        server = {
          root_url = "http://${config.networking.hostName}.local/grafana/";
          serve_from_sub_path = true;
          http_port = service-ports.grafana.internal;
          http_addr = "127.0.0.1";
        };
      };
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/grafana/" = {
        proxyPass = "http://127.0.0.1:${
            builtins.toString service-ports.grafana.internal
          }/grafana/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
        '';
      };
      locations."/netdata/" = {
        proxyPass =
          "http://127.0.0.1:${builtins.toString service-ports.netdata}/";
      };
    };
  };
}
