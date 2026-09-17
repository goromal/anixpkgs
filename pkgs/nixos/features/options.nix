{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  catalog = import ./catalog.nix;
  script = types.coercedTo (types.either types.path types.package) toString types.str;
in
{
  options.machines.features =
    lib.recursiveUpdate
      (lib.mapAttrs (_: description: {
        enable = mkOption {
          type = types.bool;
          description = "Whether to enable ${description}. Must be selected explicitly by the profile.";
        };
      }) catalog)
      {
        agents.frameworks = mkOption {
          type = types.listOf (
            types.enum [
              "claude"
              "codex"
            ]
          );
          description = "Agent CLIs to install and configure; explicitly use [] for none.";
        };
        orchestrator = {
          jobs = mkOption {
            type = types.listOf (
              types.submodule (
                { config, ... }:
                {
                  options = {
                    name = mkOption {
                      type = types.str;
                      description = "Systemd job name.";
                    };
                    jobShellScript = mkOption {
                      type = script;
                      description = "Script submitted to the orchestrator.";
                    };
                    timerCfg = mkOption {
                      type = types.attrsOf types.anything;
                      description = "Systemd timerConfig; Unit is supplied automatically.";
                    };
                    readWritePaths = mkOption {
                      type = types.listOf types.str;
                      default = [ "/" ];
                      description = "Writable paths for the job unit.";
                    };
                    execStartPre = mkOption {
                      type = types.either script (types.listOf script);
                      default = [ ];
                      description = "Commands run after the blacklist guard and before submitting the job.";
                    };
                    logTags = mkOption {
                      type = types.listOf types.str;
                      default = [ config.name ];
                      description = "Journal tags used by this job's Grafana panels.";
                    };
                  };
                }
              )
            );
            default = [ ];
            description = "Scheduled jobs; inactive when orchestrator.enable is false.";
          };
          extraPackages = mkOption {
            type = types.listOf types.package;
            default = [ ];
            description = "Additional packages on the orchestrator's PATH.";
          };
        };
        folio = {
          role = mkOption {
            type = types.enum [
              "hub"
              "spoke"
            ];
            default = "spoke";
            description = "Database ownership role.";
          };
          hubHost = mkOption {
            type = types.str;
            default = "ats.local";
            description = "Hub hostname used by a spoke.";
          };
          desktop = mkOption {
            type = types.bool;
            default = config.machines.features.desktop.enable;
            description = "Install the Folio desktop shell alongside the backend.";
          };
        };
      };

  # Force every selection even if a backend happens not to use it on this
  # architecture. This also gives CI one complete, typed feature inventory.
  config.assertions = [
    {
      assertion = builtins.deepSeq (lib.mapAttrs (
        name: _: config.machines.features.${name}.enable
      ) catalog) (builtins.deepSeq config.machines.features.agents.frameworks true);
      message = "Every profile must explicitly select all machine capabilities.";
    }
    {
      assertion =
        !config.machines.features.gameStreaming.enable
        || (config.machines.features.desktop.enable && config.machines.base.machineType == "x86_linux");
      message = "Game streaming requires an x86 desktop.";
    }
  ];
}
