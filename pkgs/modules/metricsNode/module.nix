{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.metricsNode;
  textfileDir = "/var/lib/node_exporter/textfile_collector";
  fileMonitorScript = pkgs.writeShellScriptBin "home-dir-file-counts" ''
    #!/usr/bin/env bash
    mkdir -p ${textfileDir}
    out="${textfileDir}/home_file_counts.prom"
    tmp="$(mktemp)"

    for dir in "$HOME"/*/; do
      count=$(find "$dir" -type f | wc -l)
      name=$(basename "$dir")
      echo "home_dir_file_count{dir=\"$name\"} $count" >> "$tmp"
    done

    mv "$tmp" "$out"
    chmod 644 "$out"
  '';
  dashboardConstants = import ./panels.nix;
  grafana-dash = "${anixpkgs.grafana_dash}/bin/grafana_dash";

  # Panels named in an assertion failure, so the message points at the offending
  # registration instead of leaving the reader to grep three files for it.
  panelTitles = panels: lib.concatMapStringsSep ", " (p: "'${p.title}'") panels;
  logsWithoutTag = lib.filter (p: p.kind == "logs" && p.tag == null) cfg.panels;
  queriesWithoutSource = lib.filter (
    p: p.kind != "logs" && p.metric == null && p.expr == null
  ) cfg.panels;

  # `types.listOf` concatenates definitions later-module-first, so the raw list is
  # in reverse import order: adding an unrelated import to pc-base.nix would
  # silently reshuffle every row and panel. Sorting on (dashboard, group, title)
  # makes the rendered layout depend only on the panels themselves.
  sortedPanels = builtins.sort (
    a: b:
    lib.compareLists lib.compare [ a.dashboard a.group a.title ] [ b.dashboard b.group b.title ] < 0
  ) cfg.panels;

  dashboardSpec = pkgs.writeText "grafana-spec.json" (
    builtins.toJSON {
      hostname = config.networking.hostName;
      panels = sortedPanels;
    }
  );
  # Vendored community dashboards live in anixdata, not here: every host fetches
  # the anixpkgs tarball on every upgrade, and this one file would be ~10% of it.
  # Copied to its declared name first because `sanitize` keys the output on the
  # input's basename, and a raw store path carries a hash prefix that would churn
  # the output filename on every anixdata bump.
  vendoredDashboards = [ anixpkgs.pkgData.dashboards.node-exporter-full ];
  dashboardPkg = pkgs.runCommand "anix-grafana-dashboards" { } ''
    mkdir -p $out vendor
    ${lib.concatMapStringsSep "\n" (d: ''cp ${d.data} "vendor/${d.name}"'') vendoredDashboards}
    ${grafana-dash} render --spec ${dashboardSpec} --out $out
    ${grafana-dash} sanitize vendor/*.json --out $out
    ${grafana-dash} lint $out
  '';
in
{
  options.services.metricsNode = {
    enable = lib.mkEnableOption "enable metrics node services";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to open the specific firewall port for inter-computer usage";
      default = false;
    };
    # Declared outside `config = lib.mkIf cfg.enable`, so any module can append a
    # panel without first knowing whether metrics are enabled on this host.
    panels = lib.mkOption {
      default = [ ];
      description = ''
        Panels contributed by enabled services; assembled into generated dashboards.
        Order of registration is not preserved: panels are sorted by
        (dashboard, group, title), so rows and the panels within them appear
        alphabetically. `group` is therefore how you control layout.
      '';
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            kind = lib.mkOption {
              type = lib.types.enum [
                "timeseries"
                "stat"
                "logs"
              ];
              description = "Panel style. 'logs' queries Loki; the others query Prometheus.";
            };
            title = lib.mkOption {
              type = lib.types.str;
              description = "Heading shown on the panel, and the sort key within a group.";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "General";
              description = "Row heading the panel is placed under.";
            };
            dashboard = lib.mkOption {
              type = lib.types.str;
              default = "diagnostics";
              description = ''
                Which dashboard the panel lands on. The name becomes both the
                output filename (`<name>.json`) and the dashboard uid
                (`anix-<name>`), so a typo here silently creates a second,
                nearly-empty dashboard rather than failing the build.
              '';
            };
            metric = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Prometheus metric name; shorthand for a bare PromQL query.";
            };
            expr = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Raw PromQL, overriding `metric` when both are set.";
            };
            tag = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Loki `tag` label, i.e. the unit's SYSLOG_IDENTIFIER.";
            };
            unit = lib.mkOption {
              type = lib.types.str;
              default = "short";
              description = ''
                Grafana unit id for the panel's values, e.g. `short`, `bytes`,
                `percentunit`, `s`. Grafana ignores an unrecognized id without
                complaint, and neither `grafana_dash lint` nor the assertions
                below can catch one, so a typo shows up only as unformatted axes.
              '';
            };
            width = lib.mkOption {
              type = lib.types.ints.between 1 24;
              default = 12;
              description = ''
                Panel width in columns of Grafana's 24-column grid; 12 is half
                the row. Panels wrap to a new row once a group's widths exceed 24.
              '';
            };
          };
        }
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = logsWithoutTag == [ ];
        message = "services.metricsNode.panels: every 'logs' panel must set `tag`; missing on ${panelTitles logsWithoutTag}.";
      }
      {
        assertion = queriesWithoutSource == [ ];
        message = "services.metricsNode.panels: 'timeseries'/'stat' panels must set `metric` or `expr`; missing on ${panelTitles queriesWithoutSource}.";
      }
    ];

    # Log panels are derived rather than hand-listed: every timed orchestrator job
    # gets one. `logTags` overrides the default for jobs whose `logger -t` tag
    # differs from the job name (e.g. ats-task-migrator logs as ats-grader).
    #
    # Two tags are registered by hand because they are shared channels rather
    # than job names, so nothing would derive them:
    #   - `authm`: the credential-refresh error channel several jobs emit to.
    #   - `orchestrator`: systemd derives SYSLOG_IDENTIFIER from the ExecStart
    #     basename, which is `orchestrator` for every job unit, so all job
    #     output not routed through an explicit `logger -t` lands here — as do
    #     the blacklist refusals from the orchJobGuard in pc-base.nix. It is the
    #     busiest log stream on an orchestrator host.
    services.metricsNode.panels = [
      {
        kind = "timeseries";
        title = "Home Directory Contents";
        metric = "home_dir_file_count";
        group = "Host";
        width = 24;
      }
      {
        kind = "logs";
        title = "authm Logs";
        tag = "authm";
        group = "Job Logs";
      }
      {
        kind = "logs";
        title = "orchestrator Logs";
        tag = "orchestrator";
        group = "Job Logs";
      }
    ]
    ++ lib.concatMap (
      job:
      map (t: {
        kind = "logs";
        title = "${t} Logs";
        tag = t;
        group = "Job Logs";
      }) (job.logTags or [ job.name ])
    ) globalCfg.timedOrchJobs;

    # Register Grafana in the web services landing page
    machines.base.webServices = [
      {
        name = "Grafana";
        tag = "Utilities";
        path = "/grafana/";
        description = "Metrics and monitoring dashboards";
        icon = "chart-line";
      }
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ service-ports.grafana.internal ];

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
          service_logs = {
            type = "journald";
          };
        };
        transforms = {
          tagged_service_logs = {
            type = "remap";
            inputs = [ "service_logs" ];
            source = ''
              .tag = if exists(.SYSLOG_IDENTIFIER) { .SYSLOG_IDENTIFIER } else { "unknown" }
            '';
          };
        };
        sinks = {
          prometheus = {
            # https://vector.dev/docs/reference/configuration/sinks/prometheus_exporter/
            type = "prometheus_exporter";
            inputs = [ "statsd_metrics" ];
            address = "[::]:${builtins.toString service-ports.prometheus.input}";
          };
          loki = {
            type = "loki";
            inputs = [ "tagged_service_logs" ];
            endpoint = "http://localhost:${builtins.toString service-ports.loki}";
            encoding.codec = "json"; # Recommended for structured logs
            labels = {
              job = "vector";
              host = "${config.networking.hostName}";
              tag = "{{ tag }}"; # label for filtering
            };
          };
        };
      };
    };

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        limits_config = {
          ingestion_rate_mb = 16; # Increase limit (default is 4)
          ingestion_burst_size_mb = 32; # Allow bursts above the rate
        };
        server = {
          http_listen_port = service-ports.loki;
        };
        common = {
          path_prefix = "/var/lib/loki"; # Ensures compactor has a working directory
        };
        ingester = {
          lifecycler = {
            ring = {
              kvstore = {
                store = "inmemory";
              };
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          wal = {
            enabled = true;
            dir = "/var/lib/loki/wal";
          };
        };
        schema_config = {
          configs = [
            {
              from = "2020-10-24";
              store = "boltdb-shipper";
              object_store = "filesystem";
              schema = "v11";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/index";
            cache_location = "/var/lib/loki/cache";
            # shared_store = "filesystem";
          };
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };
        limits_config.allow_structured_metadata = false;
      };
    };
    systemd.services.loki.serviceConfig = {
      Restart = lib.mkForce "on-failure";
      RestartSec = lib.mkForce "5s";
    };

    systemd.services.homeDirFileCounts = {
      description = "Generate file counts per home subdirectory";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${fileMonitorScript}/bin/home-dir-file-counts";
        Environment = "HOME=${globalCfg.homeDir}";
      };
    };
    systemd.timers.homeDirFileCounts = {
      description = "Run homeDirFileCounts every 60 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "60m";
      };
    };

    # Check health with
    # curl -s http://localhost:9001/api/v1/targets | jq '.data.activeTargets[] | {scrapeUrl, lastScrape, health, lastError}'
    services.prometheus = {
      enable = true;
      port = service-ports.prometheus.output;
      retentionTime = "15d";
      scrapeConfigs = [
        {
          job_name = "vector";
          static_configs = [
            {
              targets = [ "0.0.0.0:${builtins.toString service-ports.prometheus.input}" ];
            }
          ];
        }
        {
          job_name = "node";
          static_configs = [
            {
              targets = [ "127.0.0.1:${builtins.toString service-ports.node-exporter}" ];
            }
          ];
        }
      ];
      exporters.node = {
        enable = true;
        port = service-ports.node-exporter;
        extraFlags = [ "--collector.textfile.directory=${textfileDir}" ];
      };
    };

    # Only the node_exporter textfile collector needs a managed directory now;
    # dashboards live in the Nix store, which is already world-readable.
    systemd.tmpfiles.rules = [
      "d ${textfileDir} 0755 node-exporter node-exporter -"
    ];

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
      provision = {
        enable = true;
        dashboards.settings.providers = [
          {
            name = "anix";
            options.path = "${dashboardPkg}";
            disableDeletion = true;
            allowUiUpdates = false;
          }
        ];
        datasources.settings = {
          datasources = [
            {
              name = "Prometheus";
              uid = dashboardConstants.prometheusUid;
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:${builtins.toString service-ports.prometheus.output}";
              isDefault = true;
            }
            {
              name = "Loki";
              uid = dashboardConstants.lokiUid;
              type = "loki";
              access = "proxy";
              url = "http://localhost:${builtins.toString service-ports.loki}";
            }
          ];
          # Grafana cannot change the uid of an existing datasource through
          # provisioning: the upsert matches by name, then looks the record up
          # by the incoming uid, which does not exist yet, and aborts the whole
          # provisioner with "data source not found" -- taking the service down
          # with it. Hosts that ran the old module already have a Loki
          # datasource carrying a database-generated uid, so pinning the uids
          # above requires deleting first and letting the insert recreate them.
          # Deletes run before inserts, and naming a datasource that is absent
          # is a no-op, so this is also correct on a fresh host.
          deleteDatasources = [
            {
              name = "Prometheus";
              orgId = 1;
            }
            {
              name = "Loki";
              orgId = 1;
            }
          ];
        };
      };
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."/grafana/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString service-ports.grafana.internal}/grafana/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-Host $host;
        '';
      };
    };
  };
}
