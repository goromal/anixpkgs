# cudaNode module: reusable CUDA workload layer

## Goal

Factor the jetson-only CUDA workload config (launchpad Jupyter service + Python
package plumbing + CUDA enablement) out of `pc-base.nix` into a reusable
`pkgs/nixos/modules/cudaNode/module.nix`, and enable it on personal-dell so the
laptop gets CUDA dev tools and a CUDA-enabled launchpad, like the jetson.

## Background / constraints

- Jetson CUDA comes from the jetpack-nixos overlay +
  `hardware.nvidia-jetpack.configureCuda` (L4T, sm_8.7). x86 CUDA is stock
  nixpkgs `cudaSupport` + the desktop NVIDIA driver (already configured for
  dell in `hardware/dell.nix`). The driver/toolchain layer cannot be unified;
  the workload layer can. The module owns the common intent and branches on
  `machines.base.machineType`.
- Jetson behavior must be preserved bit-for-bit — config relocated, not changed.

## Design

### New: `pkgs/nixos/modules/cudaNode/module.nix`

Options (namespace `machines.cudaNode`, following the `machines.claude` pattern):

- `enable` — bool, default `false`.
- `pythonPackages` — `functionTo (listOf package)`, default = the scientific
  set currently in `jetpack.nix` `launchpadPythonPackages` (numpy, scipy,
  matplotlib, pandas, scikit-learn, sympy, cvxpy, statsmodels, torch, tqdm,
  pywavelets, ipyparallel, hmmlearn-with-disabled-checks, imageio, opencv4,
  geometry, pysignals, pyceres, pyceres_factors, mesh-plotter,
  find_rotational_conventions). Both jetson and dell use this default.

Config (`lib.mkIf cfg.enable`, merged branches):

- **Always:**
  - `services.launchpad.enable = true;`
  - `services.launchpad.pythonPackages = cfg.pythonPackages;`
- **Jetson branch** (`machineType == "jetson"`):
  - `hardware.nvidia-jetpack.configureCuda = true;`
- **x86 branch** (`machineType != "jetson"`):
  - `nixpkgs.config.cudaSupport = true;` (no `cudaCapabilities` pin — maximizes
    cuda-maintainers cache hits; fat binaries are acceptable)
  - `nix.settings.substituters = [ "https://cuda-maintainers.cachix.org" ];`
  - `nix.settings.trusted-public-keys = [ "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" ];`
  - `environment.systemPackages = [ pkgs.cudaPackages.cudatoolkit pkgs.cudaPackages.cudnn ];`
  - Assertion: `services.xserver.videoDrivers` contains `"nvidia"` with message
    pointing at the machine's hardware file (catches enabling cudaNode on a
    GPU-less machine).

### Modified: `pkgs/nixos/pc-base.nix`

- Add `./modules/cudaNode/module.nix` to imports.
- Remove `hardware.nvidia-jetpack.configureCuda` line and the
  `services.launchpad.enable` / `services.launchpad.pythonPackages` mkIf-jetson
  lines (288–293).
- Remove the `machines.base.launchpadPythonPackages` option (subsumed by
  `machines.cudaNode.pythonPackages`).

### Modified: `pkgs/nixos/profiles/jetpack.nix`

- Remove `launchpadPythonPackages` from the `mkProfileConfig` arg set.
- Add `machines.cudaNode.enable = true;` to the second attrset of
  `recursiveUpdate` (alongside `machines.claude`). Uses the module's default
  `pythonPackages` (identical list).

### Modified: `pkgs/nixos/configurations/personal-dell.nix`

- Add `machines.cudaNode.enable = true;`.

## Verification

1. **Jetson regression (eval-only):** `nix-instantiate` / dry-build of the
   jetpack-orin-nx configuration evaluates successfully (aarch64 full build not
   required on the laptop; evaluation catches option-plumbing errors).
2. **Dell deploy:** `anix-upgrade --local -s <repo>` succeeds (expect a long
   first build/download even with the cache; torch CUDA closure is multi-GB).
3. `nvcc --version` works; `python3 -c "import torch; print(torch.cuda.is_available())"`
   from the launchpad env prints `True`.
4. Launchpad Jupyter reachable at `http://atorgesen-dell.local/lab/`.
5. nvtop shows GPU activity while a small torch matmul runs on `cuda:0`.

## Out of scope

- Pinning cudaCapabilities (revisit if cache hit rate disappoints).
- CUDA-enabling other system services; only launchpad + dev tools.
