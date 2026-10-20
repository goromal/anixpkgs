{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.bitd;
  anixPkgs = if pkgs ? bit-rs then pkgs else pkgs.extend (import ../../../overlay.nix);
  ports = import ../../nixos/service-ports.nix;
  # Cozy checks restart ComfyUI after their job so it frees the RAM its loaded
  # models hold. --no-block keeps the stop/start out of the check's deadline;
  # authorization (the comfyui module's polkit rule) is still checked up front.
  comfyuiRestart = [
    "${pkgs.systemd}/bin/systemctl"
    "--no-block"
    "restart"
    "comfyui.service"
  ];
  json = pkgs.formats.json { };
  known = builtins.attrNames cfg.plugins;
  selected = lib.unique cfg.checks;
  valid = builtins.filter (name: builtins.hasAttr name cfg.plugins) selected;
  configuration = json.generate "bitd.json" {
    listen = "127.0.0.1:${toString cfg.port}";
    checks = map (
      name:
      let
        plugin = cfg.plugins.${name};
      in
      {
        inherit name;
        inherit (plugin) kind command;
        timeout_ms = plugin.timeoutMs;
        config = plugin.settings;
      }
      // lib.optionalAttrs (plugin.kind == "health") { rate_hz = plugin.rateHz; }
      // lib.optionalAttrs plugin.exclusive { exclusive = true; }
    ) valid;
  };
in
{
  options.services.bitd = {
    enable = lib.mkEnableOption "machine built-in tests";
    package = lib.mkOption {
      type = lib.types.package;
      default = anixPkgs.bit-rs;
      description = "Package containing bitd, bitctl, and initial plugin outputs.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = ports.bitd;
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = "andrew";
      description = "User that bitd and its plugins run as.";
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "dev";
    };
    checks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Plugin names to install and run. Lists contributed by modules are merged and deduplicated.";
    };
    plugins = lib.mkOption {
      default = { };
      description = "Runtime plugin definitions and per-machine configuration.";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            kind = lib.mkOption {
              type = lib.types.enum [
                "health"
                "regression"
              ];
            };
            command = lib.mkOption {
              type = lib.types.str;
              description = "Absolute executable implementing the BIT stdin JSON / exit status interface.";
            };
            rateHz = lib.mkOption {
              type = lib.types.nullOr lib.types.float;
              default = null;
            };
            timeoutMs = lib.mkOption {
              type = lib.types.ints.positive;
              default = 4000;
            };
            exclusive = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Regression only: never run alongside another regression check (e.g. it needs the GPU to itself).";
            };
            settings = lib.mkOption {
              type = lib.types.attrsOf json.type;
              default = { };
            };
          };
        }
      );
    };
  };
  config = lib.mkIf cfg.enable {
    # Every machine with bitd watches for failed or crash-looping system units.
    services.bitd.checks = [ "systemd_units" ];
    services.bitd.plugins = {
      internet = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.internet}/bin/bit-check-internet";
        rateHz = lib.mkDefault 0.2;
        timeoutMs = lib.mkDefault 4500;
      };
      avahi = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.avahi}/bin/bit-check-avahi";
        rateHz = lib.mkDefault 0.2;
        settings.hostname = lib.mkDefault "${config.networking.hostName}.local";
      };
      # Units that merge Nix-managed settings into each agent's config file.
      claude_settings = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.user_units}/bin/bit-check-user-units";
        rateHz = lib.mkDefault (1.0 / 60.0);
        settings.units = lib.mkDefault [ "claude-settings-update.service" ];
      };
      codex_settings = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.user_units}/bin/bit-check-user-units";
        rateHz = lib.mkDefault (1.0 / 60.0);
        settings.units = lib.mkDefault [ "codex-settings-update.service" ];
      };
      systemd_units = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.systemd_units}/bin/bit-check-systemd-units";
        rateHz = lib.mkDefault (1.0 / 30.0);
        settings = {
          max_restarts = lib.mkDefault 3;
          window_seconds = lib.mkDefault 600;
          # Unit names expected to fail or restart often on this machine.
          ignore = lib.mkDefault [ ];
        };
      };
      nvidia_power = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.nvidia_power}/bin/bit-check-nvidia-power";
        # Every 5 minutes: each query wakes a runtime-suspended laptop dGPU.
        rateHz = lib.mkDefault (1.0 / 300.0);
        timeoutMs = lib.mkDefault 15000;
        settings.nvidia_smi = lib.mkDefault "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
      };
      cozy_imgedit2 = {
        kind = "regression";
        exclusive = lib.mkDefault true;
        command = lib.mkDefault "${cfg.package.cozy_imgedit2}/bin/bit-check-cozy-imgedit2";
        timeoutMs = lib.mkDefault 900000;
        settings = {
          url = lib.mkDefault "http://127.0.0.1:${toString ports.cozy}/cozy";
          token_file = lib.mkDefault "${config.machines.base.homeDir}/secrets/flask/cozy-api-token";
          png_command = lib.mkDefault "${anixPkgs.png}/bin/png";
          # Reserve time for upload, HTTP deadlines, and cancelling the job.
          max_seconds = lib.mkDefault 870;
          restart_command = lib.mkDefault comfyuiRestart;
        };
      };
      cozy_imggen_quantized = {
        kind = "regression";
        exclusive = lib.mkDefault true;
        command = lib.mkDefault "${cfg.package.cozy_imggen_quantized}/bin/bit-check-cozy-imggen-quantized";
        # 60 s job budget plus HTTP deadlines and cancelling the job.
        timeoutMs = lib.mkDefault 90000;
        settings = {
          url = lib.mkDefault "http://127.0.0.1:${toString ports.cozy}/cozy";
          token_file = lib.mkDefault "${config.machines.base.homeDir}/secrets/flask/cozy-api-token";
          max_seconds = lib.mkDefault 60;
          width = lib.mkDefault 500;
          height = lib.mkDefault 500;
          restart_command = lib.mkDefault comfyuiRestart;
        };
      };
      ardupilot = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.ardupilot}/bin/bit-check-ardupilot";
        rateHz = lib.mkDefault 0.2;
        timeoutMs = lib.mkDefault 4500;
        settings = {
          address = lib.mkDefault "127.0.0.1:${toString ports.mavlink.router-tcp}";
          max_seconds = lib.mkDefault 3;
        };
      };
      # Needs settings.ros2 (the machine's ros2 CLI) and settings.topics.
      ros2_topics = {
        kind = "health";
        command = lib.mkDefault "${cfg.package.ros2_topics}/bin/bit-check-ros2-topics";
        # Each run starts the Python ros2 CLI once per topic.
        rateHz = lib.mkDefault (1.0 / 15.0);
        timeoutMs = lib.mkDefault 12000;
        settings.max_seconds = lib.mkDefault 8;
      };
    };
    assertions = [
      {
        assertion = builtins.all (name: lib.elem name known) selected;
        message = "Unknown services.bitd.checks: ${
          lib.concatStringsSep ", " (builtins.filter (name: !(lib.elem name known)) selected)
        }";
      }
      {
        assertion = builtins.all (
          name:
          let
            p = cfg.plugins.${name};
          in
          p.timeoutMs <= 86400000
          && (
            if p.kind == "health" then
              p.rateHz != null && p.rateHz >= 0.00001 && p.rateHz <= 100.0
            else
              p.rateHz == null
          )
        ) valid;
        message = "bitd health plugins need a positive rateHz <= 100; regression plugins must omit rateHz; timeoutMs must be <= 86400000.";
      }
      {
        assertion = builtins.all (
          name: cfg.plugins.${name}.exclusive -> cfg.plugins.${name}.kind == "regression"
        ) valid;
        message = "Only bitd regression plugins can be exclusive.";
      }
    ];
    environment.systemPackages = [ cfg.package ];
    environment.shellAliases.b = "bitctl";
    environment.etc."bitd.json".source = configuration;
    environment.sessionVariables.BITD_ENDPOINT = "http://127.0.0.1:${toString cfg.port}";
    systemd.services.bitd = {
      description = "Machine health and regression checks";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [
        pkgs.systemd
        pkgs.avahi
      ];
      serviceConfig = {
        ExecStartPre = "${cfg.package}/bin/bitd --config ${configuration} --check-config";
        ExecStart = "${cfg.package}/bin/bitd --config ${configuration}";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 10;
        KillMode = "control-group";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}
