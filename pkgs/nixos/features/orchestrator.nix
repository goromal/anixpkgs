{
  config,
  pkgs,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.machines.base;
  features = config.machines.features;
  inherit (import ../runtime.nix { inherit config pkgs lib; }) atsudo machine-rcrsync machine-authm;
in
{
  config = lib.mkMerge [
    {
      # Orchestrator jobs
      services.orchestratord = lib.mkIf features.orchestrator.enable {
        enable = true;
        orchestratorPkg = anixpkgs.orchestrator;
        threads = 2;
        pathPkgs =
          with pkgs;
          [
            bash
            coreutils
            util-linux
            rclone
            machine-rcrsync
            machine-authm
            anixpkgs.mp4
            anixpkgs.mp4unite
            anixpkgs.png
            anixpkgs.scrape
          ]
          ++ features.orchestrator.extraPackages;
        statsdPort = lib.mkIf features.metrics.enable service-ports.statsd;
      };
      # Metric panels are registered by the services that emit them. Both the
      # orchestrator and tactical panels live in one assignment because Nix
      # forbids assigning `services.metricsNode.panels` twice in this attrset.
      services.metricsNode.panels =
        lib.optionals features.orchestrator.enable [
          {
            kind = "timeseries";
            title = "Completed Jobs";
            metric = "orchestrator_jobs_completed";
            group = "Orchestrator";
          }
          {
            kind = "timeseries";
            title = "Discarded Jobs";
            metric = "orchestrator_jobs_discarded";
            group = "Orchestrator";
          }
          {
            kind = "timeseries";
            title = "Queued Jobs";
            metric = "orchestrator_jobs_queued";
            group = "Orchestrator";
          }
        ]
        ++ lib.optionals features.tactical.enable [
          {
            kind = "timeseries";
            title = "Tactical Visits";
            metric = "tactical_page_visits";
            group = "Tactical";
          }
        ];

      systemd.timers."weekly-orchestratord-restart" = lib.mkIf features.orchestrator.enable {
        description = "Restart orchestratord weekly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 03:00";
          Persistent = true;
        };
      };
      systemd.services."weekly-orchestratord-restart" = lib.mkIf features.orchestrator.enable {
        description = "Restart orchestratord weekly";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl restart orchestratord.service";
        };
      };

      environment.systemPackages = (
        if features.orchestrator.enable then
          [
            (
              let
                servicelist = builtins.concatStringsSep "/" (
                  map (x: "${x.name}.service") features.orchestrator.jobs
                );
                triggerscript = ../otrigger.py;
              in
              pkgs.writeShellScriptBin "otrigger" ''
                servicelist="${builtins.toString servicelist}"
                tmpdir=$(mktemp -d)
                ${pkgs.python3}/bin/python ${triggerscript} "$servicelist" 2> $tmpdir/selection
                serviceselection=$(cat $tmpdir/selection)
                rm -r $tmpdir
                if [[ ! -z "$serviceselection" ]]; then
                  echo "sudo systemctl restart ''${serviceselection}"
                  ${atsudo}/bin/atsudo systemctl restart ''${serviceselection}
                fi
              ''
            )
          ]
        else
          [ ]
      );
    }
    (
      let
        # On-disk blacklist: a marker file named after a job in this directory
        # causes that job's oneshot service to fail immediately instead of
        # submitting to orchestratord. Managed via the orchestrator UI.
        orchBlacklistDir = "${cfg.homeDir}/configs/orchestrator-blacklist.d";
        orchJobGuard = pkgs.writeShellScript "orch-job-guard" ''
          name="$1"
          if [ -e "${orchBlacklistDir}/$name" ]; then
            ${pkgs.util-linux}/bin/logger -t orchestrator "Job '$name' is blacklisted; refusing to run"
            echo "Orchestrator job '$name' is blacklisted by ${orchBlacklistDir}/$name" >&2
            exit 1
          fi
        '';
      in
      lib.mkIf features.orchestrator.enable {
        systemd.tmpfiles.rules = [
          "d ${orchBlacklistDir} 0775 andrew dev -"
        ];
        systemd.timers = builtins.listToAttrs (
          map (job: {
            name = job.name;
            value = {
              description = "${job.name} trigger timer";
              wantedBy = [ "timers.target" ];
              timerConfig = job.timerCfg // {
                Unit = "${job.name}.service";
              };
            };
          }) features.orchestrator.jobs
        );
        systemd.services = builtins.listToAttrs (
          map (job: {
            name = job.name;
            value = {
              enable = true;
              description = "${job.name} oneshot service";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${anixpkgs.orchestrator}/bin/orchestrator bash 'bash ${job.jobShellScript}'";
                ReadWritePaths = job.readWritePaths;
                # Blacklist guard runs first for every job, then any
                # job-specific ExecStartPre.
                ExecStartPre = [
                  "${orchJobGuard} ${job.name}"
                ]
                ++ lib.toList job.execStartPre;
              };
            };
          }) features.orchestrator.jobs
        );
      }
    )
  ];
}
