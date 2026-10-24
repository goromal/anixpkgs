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

  # UI usage: every page served through nginx carries a heartbeat (see
  # webserverNode) that POSTs here while the page is visible and in use. Spokes
  # forward their heartbeats to the hub, which turns everyone's into one
  # Prometheus counter and hands the raw events to Tactical's archive.
  usageCfg = cfg.usage;
  usageBeaconPath = "/anix-usage";
  usageBeaconLocation = {
    proxyPass = "http://127.0.0.1:${toString service-ports.usage.beacon}${usageBeaconPath}";
    extraConfig = ''
      limit_except POST { deny all; }
      client_max_body_size 1k;
    '';
  };
  # Disk-buffered so heartbeats survive the hub (or Tactical) being down, or a
  # laptop being off the LAN, and are delivered when it comes back. 256 MiB is
  # Vector's minimum disk buffer; heartbeats are ~150 bytes each.
  usageDiskBuffer = {
    type = "disk";
    max_size = 268435488;
    when_full = "drop_newest";
  };
  # Heartbeats are trusted only as far as their shape: the page could be any
  # script on the LAN, so anything outside the known enums or a sane heartbeat
  # length is dropped rather than becoming a stray pie slice or a huge count.
  usageValidate = ''
    service = string(.service) ?? ""
    category = string(.category) ?? ""
    device = string(.device) ?? ""
    seconds = to_int(.seconds) ?? 0
    if service == "" || strlen(service) > 64 ||
       !includes(${builtins.toJSON (import ../../nixos/web-categories.nix)}, category) ||
       !includes(["desktop", "mobile"], device) ||
       seconds <= 0 || seconds > 60 {
      abort
    }
    . = {
      "timestamp": now(),
      "host": "${config.networking.hostName}",
      "service": service,
      "category": category,
      "device": device,
      "seconds": seconds
    }
  '';

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
  vendoredDashboards = with anixpkgs.pkgData.dashboards; [
    node-exporter-full
    nix-exporter
  ];
  dashboardPkg = pkgs.runCommand "anix-grafana-dashboards" { } ''
    mkdir -p $out vendor
    ${lib.concatMapStringsSep "\n" (d: ''cp ${d.data} "vendor/${d.name}"'') vendoredDashboards}
    ${grafana-dash} render --spec ${dashboardSpec} --out $out
    ${grafana-dash} sanitize vendor/*.json --out $out
    ${grafana-dash} lint $out
  '';
in
{
  # Upstream's module, imported from the packaged source so the unit definitions
  # track the pinned exporter. Its `self` argument only supplies the default
  # `package`, which is always overridden below, so it is never forced.
  imports = [
    (import "${anixpkgs.nix-exporter.src}/nix/module.nix" {
      self = throw "nix-exporter: services.nix-exporter.package must be set explicitly";
    })
  ];

  options.services.metricsNode = {
    enable = lib.mkEnableOption "enable metrics node services";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to open the specific firewall port for inter-computer usage";
      default = false;
    };
    retentionTime = lib.mkOption {
      type = lib.types.str;
      default = if cfg.usage.isHub then "400d" else "15d";
      description = ''
        How long Prometheus keeps samples. The hub keeps a year and change so
        UI usage can be charted over a year; spokes only need recent history.
      '';
    };
    usage = {
      isHub = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Collect every host's UI usage here instead of forwarding it to `hubHost`.";
      };
      hubHost = lib.mkOption {
        type = lib.types.str;
        default = "ats.local";
        description = "Host a spoke forwards UI usage heartbeats to.";
      };
      archiveUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Hub only: HTTP endpoint that receives raw usage events as NDJSON and
          keeps the durable record. Null keeps usage in Prometheus alone.
        '';
      };
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
            legend = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Grafana legend template for a Prometheus panel, e.g. `{{dir}}` to
                label each series by its `dir` label. Defaults to `{{instance}}`,
                the scrape target's host:port -- correct only when a metric has
                one series per host, and wrong for a metric that fans out over
                another label, where every series would collapse to the same
                host:port line. Ignored by `logs` panels.
              '';
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
        legend = "{{dir}}";
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
    ++ lib.optionals usageCfg.isHub [
      {
        kind = "timeseries";
        title = "UI Active Time by Category";
        expr = "sum by (category) (increase(anix_ui_active_seconds_total[1h])) / 60";
        legend = "{{category}}";
        unit = "m";
        group = "UI Usage";
        dashboard = "usage";
      }
      {
        kind = "timeseries";
        title = "UI Active Time by Device";
        expr = "sum by (device) (increase(anix_ui_active_seconds_total[1h])) / 60";
        legend = "{{device}}";
        unit = "m";
        group = "UI Usage";
        dashboard = "usage";
      }
      {
        kind = "timeseries";
        title = "UI Active Time by Service";
        expr = "sum by (service) (increase(anix_ui_active_seconds_total[1h])) / 60";
        legend = "{{service}}";
        unit = "m";
        group = "UI Usage";
        dashboard = "usage";
        width = 24;
      }
    ]
    ++ lib.optionals config.machines.features.orchestrator.enable (
      lib.concatMap (
        job:
        map (t: {
          kind = "logs";
          title = "${t} Logs";
          tag = t;
          group = "Job Logs";
        }) job.logTags
      ) config.machines.features.orchestrator.jobs
    );

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

    networking.firewall.allowedTCPPorts =
      lib.optional cfg.openFirewall service-ports.grafana.internal
      ++ lib.optional usageCfg.isHub service-ports.usage.hub;

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
          usage_beacons = {
            # https://vector.dev/docs/reference/configuration/sources/http_server/
            type = "http_server";
            address = "127.0.0.1:${toString service-ports.usage.beacon}";
            path = usageBeaconPath;
            method = "POST";
            decoding.codec = "json";
          };
        }
        // lib.optionalAttrs usageCfg.isHub {
          usage_remote = {
            # https://vector.dev/docs/reference/configuration/sources/vector/
            type = "vector";
            address = "0.0.0.0:${toString service-ports.usage.hub}";
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
          usage_events = {
            type = "remap";
            inputs = [ "usage_beacons" ];
            source = usageValidate;
          };
        }
        // lib.optionalAttrs usageCfg.isHub {
          usage_metrics = {
            # https://vector.dev/docs/reference/configuration/transforms/log_to_metric/
            type = "log_to_metric";
            inputs = [
              "usage_events"
              "usage_remote"
            ];
            metrics = [
              {
                type = "counter";
                field = "seconds";
                increment_by_value = true;
                name = "anix_ui_active_seconds_total";
                tags = {
                  service = "{{ service }}";
                  category = "{{ category }}";
                  device = "{{ device }}";
                  host = "{{ host }}";
                };
              }
            ];
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
        }
        // (
          if usageCfg.isHub then
            {
              usage_prometheus = {
                # Its own exporter rather than the statsd one: Vector expires a
                # series once it goes `flush_period_secs` without an update, and a
                # usage series idle for an evening must keep counting from where
                # it left off instead of reappearing as a fresh counter.
                type = "prometheus_exporter";
                inputs = [ "usage_metrics" ];
                address = "127.0.0.1:${toString service-ports.usage.exporter}";
                flush_period_secs = 31536000;
                # Otherwise each sample carries its last heartbeat's time: every
                # scrape after the first is dropped as a duplicate, and the series
                # goes stale 5m after you stop using a UI, so instant queries and
                # short-range increase() come back empty.
                suppress_timestamp = true;
              };
            }
            // lib.optionalAttrs (usageCfg.archiveUrl != null) {
              usage_archive = {
                # https://vector.dev/docs/reference/configuration/sinks/http/
                type = "http";
                inputs = [
                  "usage_events"
                  "usage_remote"
                ];
                uri = usageCfg.archiveUrl;
                method = "post";
                encoding.codec = "json";
                framing.method = "newline_delimited";
                buffer = usageDiskBuffer;
              };
            }
          else
            {
              usage_forward = {
                # https://vector.dev/docs/reference/configuration/sinks/vector/
                type = "vector";
                inputs = [ "usage_events" ];
                address = "${usageCfg.hubHost}:${toString service-ports.usage.hub}";
                buffer = usageDiskBuffer;
                # The hub being unreachable at startup is routine (laptops roam);
                # the buffer covers it, so it should not read as a failure.
                healthcheck.enabled = false;
              };
            }
        );
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
      inherit (cfg) retentionTime;
      # A ceiling under the time limit, so a series explosion on the hub cannot
      # quietly fill the disk over 400 days.
      extraFlags = [ "--storage.tsdb.retention.size=10GB" ];
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
          job_name = "nix";
          static_configs = [
            {
              targets = [ "127.0.0.1:${builtins.toString service-ports.nix-exporter}" ];
            }
          ];
        }
      ]
      ++ lib.optionals usageCfg.isHub [
        {
          job_name = "usage";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString service-ports.usage.exporter}" ];
            }
          ];
        }
      ]
      ++ [
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

    # Nix store, daemon, build and upkeep metrics, charted by the vendored
    # nix-exporter dashboard. Listens on loopback only; Prometheus is local.
    services.nix-exporter = {
      enable = true;
      package = anixpkgs.nix-exporter;
      nixPackage = config.nix.package;
      port = service-ports.nix-exporter;
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
        security.secret_key = "SW2YcwTIb9zpOOhoPsMm";
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
    # Services on their own port answer heartbeats on their own origin, since
    # the injected page script posts same-origin.
    services.nginx.virtualHosts =
      lib.listToAttrs (
        map (s: {
          name = "${config.networking.hostName}.local:${toString s.port}";
          value.locations."= ${usageBeaconPath}" = usageBeaconLocation;
        }) (lib.filter (s: s.port != null) globalCfg.webServices)
      )
      // {
        "${config.networking.hostName}.local" = {
          locations."= ${usageBeaconPath}" = usageBeaconLocation;
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
  };
}
