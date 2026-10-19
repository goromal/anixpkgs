{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.machines.cudaNode;
  # The system package set stays CPU-only so unrelated packages neither rebuild
  # with CUDA nor pull CUDA into their closures. GPU workloads (launchpad,
  # ComfyUI) instead draw from this second instance of the same Nixpkgs, which
  # shares the system's config (cudaCapabilities, allowUnfree, ...) and overlays
  # but turns cudaSupport on.
  cudaPkgs = import pkgs.path {
    localSystem = config.nixpkgs.hostPlatform;
    config = config.nixpkgs.config // {
      cudaSupport = true;
    };
    overlays = config.nixpkgs.overlays;
  };
in
{
  options.machines.cudaNode = {
    enable = lib.mkEnableOption "CUDA development tooling";
    pkgs = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
      default = if cfg.enable then cudaPkgs else pkgs;
      defaultText = lib.literalMD "a CUDA-enabled Nixpkgs instance when enabled, else `pkgs`";
      description = ''
        Package set for GPU-accelerated workloads such as launchpad and ComfyUI:
        the system Nixpkgs with `cudaSupport = true` on CUDA machines, or the
        plain system `pkgs` elsewhere.
      '';
    };
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
