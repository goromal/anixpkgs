# personal-dell NVIDIA Driver + nvtop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable the proprietary NVIDIA driver (PRIME offload) and nvtop GPU monitoring on personal-dell only.

**Architecture:** All config goes in `pkgs/nixos/hardware/dell.nix`, which is imported only by `configurations/personal-dell.nix`, so GPU-less personal machines are untouched by construction. Spec: `docs/superpowers/specs/2026-06-10-dell-nvidia-nvtop-design.md`.

**Tech Stack:** NixOS (anixpkgs), `hardware.nvidia` module, nvtopPackages.full.

---

### Task 1: Add NVIDIA driver + nvtop to dell hardware config and deploy

**Goal:** dell.nix configures the open NVIDIA kernel module in PRIME offload mode with fine-grained power management, installs nvtop, and the system builds and switches.

**Files:**
- Modify: `pkgs/nixos/hardware/dell.nix` (append before closing `}`)

**Acceptance Criteria:**
- [ ] `anix-upgrade --local -s /data/andrew/dev/anix/sources/anixpkgs` completes without error
- [ ] New generation contains nvidia driver: `nixos-rebuild` switch output shows no failures and `cat /proc/driver/nvidia/version` works after reboot
- [ ] `nvtop` binary on PATH in new generation

**Verify:** `anix-upgrade --local -s /data/andrew/dev/anix/sources/anixpkgs` → "switching to configuration" succeeds; `which nvtop` → store path

**Steps:**

- [ ] **Step 1: Edit `pkgs/nixos/hardware/dell.nix`** — add before the final closing brace:

```nix
  # NVIDIA RTX 500 Ada dGPU: PRIME offload (Intel iGPU drives displays)
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    prime = {
      offload.enable = true;
      offload.enableOffloadCmd = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
  environment.systemPackages = [ pkgs.nvtopPackages.full ];
```

- [ ] **Step 2: Confirm file is tracked** (it is an existing tracked file, but verify):

Run: `git -C /data/andrew/dev/anix/sources/anixpkgs ls-files pkgs/nixos/hardware/dell.nix`
Expected: prints the path

- [ ] **Step 3: Deploy**

Run: `anix-upgrade --local -s /data/andrew/dev/anix/sources/anixpkgs`
Expected: build succeeds, switches to new generation. Note: switching from nouveau to nvidia typically requires a reboot for the driver to load.

- [ ] **Step 4: Commit**

```bash
git -C /data/andrew/dev/anix/sources/anixpkgs add pkgs/nixos/hardware/dell.nix docs/superpowers/specs/2026-06-10-dell-nvidia-nvtop-design.md docs/superpowers/plans/2026-06-10-dell-nvidia-nvtop.md docs/superpowers/plans/2026-06-10-dell-nvidia-nvtop.md.tasks.json
git -C /data/andrew/dev/anix/sources/anixpkgs commit -m "feat: enable NVIDIA driver (PRIME offload) + nvtop on personal-dell"
```

### Task 2: Reboot and verify GPU monitoring

**Goal:** After reboot, the proprietary driver is loaded and nvtop shows both GPUs.

**Files:**
- None (verification only)

**Acceptance Criteria:**
- [ ] `lsmod | grep nvidia` shows nvidia modules loaded (nouveau absent)
- [ ] `nvidia-smi` lists "NVIDIA RTX 500 Ada Generation Laptop GPU"
- [ ] `nvtop` runs and displays the NVIDIA GPU (and Intel iGPU)
- [ ] Display still works (user confirms desktop renders on Intel iGPU)

**Verify:** `nvidia-smi --query-gpu=name --format=csv,noheader` → `NVIDIA RTX 500 Ada Generation Laptop GPU`

**Steps:**

- [ ] **Step 1: User reboots the machine** (driver swap nouveau → nvidia requires it)

- [ ] **Step 2: Verify driver loaded**

Run: `lsmod | grep -E "^(nvidia|nouveau)"`
Expected: nvidia modules listed, no nouveau

- [ ] **Step 3: Verify nvidia-smi**

Run: `nvidia-smi --query-gpu=name --format=csv,noheader`
Expected: `NVIDIA RTX 500 Ada Generation Laptop GPU`

- [ ] **Step 4: Verify nvtop**

Run: `nvtop --version` then user runs `nvtop` interactively
Expected: version prints; interactive view shows both GPUs

- [ ] **Step 5: Sanity-check CUDA visibility (optional)**

Run: `nix run nixpkgs#cudaPackages.cuda_nvml_dev 2>/dev/null || true` — skip; nvidia-smi success is sufficient evidence the CUDA driver stack is present.
