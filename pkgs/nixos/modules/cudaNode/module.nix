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
    enable = lib.mkEnableOption "CUDA workload node (launchpad Jupyter server + CUDA dev tooling)";
    pythonPackages = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      description = "Python packages for the launchpad Jupyter server (function from python313 package set to list)";
      default =
        ps: with ps; [
          numpy
          scipy
          matplotlib
          pandas
          scikit-learn
          sympy
          cvxpy
          statsmodels
          torch
          tqdm
          pywavelets
          ipyparallel
          (hmmlearn.overridePythonAttrs (_: {
            nativeCheckInputs = [ ];
          }))
          imageio
          opencv4
          geometry
          pysignals
          pyceres
          pyceres_factors
          mesh-plotter
          find_rotational_conventions
        ];
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.launchpad.enable = true;
      services.launchpad.pythonPackages = cfg.pythonPackages;
    }
    (lib.mkIf (config.machines.base.machineType == "jetson") {
      hardware.nvidia-jetpack.configureCuda = true;
    })
    (lib.mkIf (config.machines.base.machineType != "jetson") {
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
    })
  ]);
}
