{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.machines.cudaNode;
in
{
  options.machines.cudaNode = {
    enable = lib.mkEnableOption "CUDA development tooling";
  };

  config = lib.mkIf cfg.enable (
    lib.mkIf (config.machines.base.machineType != "jetson") {
      nixpkgs.config.cudaSupport = true;
      nix.settings.substituters = [ "https://cuda-maintainers.cachix.org" ];
      nix.settings.trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
      environment.systemPackages = [
        pkgs.cudaPackages.cudatoolkit
        pkgs.cudaPackages.cudnn
      ];
      assertions = [
        {
          assertion = lib.elem "nvidia" config.services.xserver.videoDrivers;
          message = "machines.cudaNode on a non-jetson machine requires the proprietary NVIDIA driver; add it to the machine's hardware file (see pkgs/nixos/hardware/dell.nix).";
        }
      ];
    }
  );
}
