{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.aiart;
  comfy = config.services.comfyui;
  service-ports = import ../../nixos/service-ports.nix;
  extendedPkgs = if pkgs ? aiart then pkgs else pkgs.extend (import ../../../overlay.nix);
in
{
  options.services.aiart = {
    enable = lib.mkEnableOption "aiart agent-driven 2D and 3D art workflows";
    package = lib.mkOption {
      type = lib.types.package;
      default = extendedPkgs.aiart;
    };
    projectsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.machines.base.homeDir}/data/aiart";
      description = "Where aiart projects live, one directory each.";
    };
    agents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "claude"
        "codex"
      ];
      description = "Agent CLIs the TUI offers, in key order (c, x).";
    };
    backends = {
      image = lib.mkOption {
        type = lib.types.str;
        default = "imggen21";
        description = "cozy workflow for text-to-image.";
      };
      edit = lib.mkOption {
        type = lib.types.str;
        default = "imgedit4";
        description = "cozy workflow for prompt-driven image edits.";
      };
      mesh = lib.mkOption {
        type = lib.types.str;
        default = "hunyuan3d21";
        description = "aiart mesh workflow for image-to-3D (bundled or from workflowDirs).";
      };
    };
    workflowDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "${cfg.projectsDir}/workflows" ];
      description = "Extra directories of <name>.api.json mesh workflows; later entries override bundled ones.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.machines.cudaNode.enable && comfy.enable && comfy.cozy.enable;
        message = "services.aiart needs a GPU node running ComfyUI and cozy (features gpu + imageGeneration).";
      }
      {
        assertion = lib.all (w: lib.elem w comfy.cozy.workflows) [
          cfg.backends.image
          cfg.backends.edit
        ];
        message = "services.aiart.backends.image/edit must be listed in services.comfyui.cozy.workflows.";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."aiart/config.json".text = builtins.toJSON {
      inherit (cfg) projectsDir agents workflowDirs;
      backends = cfg.backends;
      cozyUrl = "http://127.0.0.1:${toString service-ports.cozy}/cozy";
      comfyUrl = "http://127.0.0.1:${toString comfy.port}";
      comfyModelsDir = "${comfy.dataDir}/models";
      cozyInputDir = "${comfy.dataDir}/input";
    };

    machines.agents.privateSkills = [
      "aiart-image"
      "aiart-3d"
    ];
  };
}
