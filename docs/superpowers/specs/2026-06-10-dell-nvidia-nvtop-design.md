# personal-dell: NVIDIA proprietary driver + nvtop

## Goal

Enable GPU monitoring (htop-style) and CUDA-capable drivers on the personal-dell
machine (Intel Meteor Lake iGPU + NVIDIA RTX 500 Ada laptop dGPU), without
affecting GPU-less personal machines (inspiron, panasonic).

## Design

All changes go in `pkgs/nixos/hardware/dell.nix`, which is imported only by
`configurations/personal-dell.nix` — other machines are untouched by construction.

Add to `hardware/dell.nix`:

- `services.xserver.videoDrivers = [ "nvidia" ];` (required to load the driver;
  Intel remains primary display)
- `hardware.nvidia`:
  - `modesetting.enable = true;`
  - `open = true;` (Ada generation is fully supported by the open kernel module)
  - `powerManagement.enable = true;` and `powerManagement.finegrained = true;`
    (dGPU powers down when idle)
  - `prime.offload.enable = true;` + `prime.offload.enableOffloadCmd = true;`
    (provides the `nvidia-offload` wrapper for graphical apps)
  - `prime.intelBusId = "PCI:0:2:0";` / `prime.nvidiaBusId = "PCI:1:0:0";`
    (from lspci: Intel 00:02.0, NVIDIA 01:00.0)
- `environment.systemPackages = [ pkgs.nvtop ];` (or `pkgs.nvtopPackages.full`
  per current nixpkgs naming)

CUDA compute (PyTorch etc.) is unaffected by offload mode — CUDA talks directly
to the driver; the dGPU wakes on demand and sleeps after.

## Verification

1. `anix-upgrade --local -s <repo>` builds and switches successfully.
2. After reboot (driver swap from nouveau requires it): `nvidia-smi` shows the
   RTX 500 Ada.
3. `nvtop` runs and displays both Intel and NVIDIA GPUs.
4. Displays/suspend still work on the Intel iGPU.

## Future work (out of scope)

Factor jetson CUDA package set (`profiles/jetpack.nix`) into a reusable
`pkgs/nixos/modules/cudaNode/module.nix`, optionally enabled in `pc-base.nix`,
so personal-dell gets CUDA-enabled packages like the jetson profile.
