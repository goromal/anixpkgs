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
    lib.mkMerge [
      {
        # The former cuda-maintainers cache was retired in favor of the
        # nix-community cache and now returns HTTP 401 for every lookup.
        nix.settings.substituters = [ "https://nix-community.cachix.org" ];
        nix.settings.trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      }
      (lib.mkIf (config.machines.base.machineType != "jetson") {
        nixpkgs.config.cudaSupport = true;
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
      })
    ]
  );
}
