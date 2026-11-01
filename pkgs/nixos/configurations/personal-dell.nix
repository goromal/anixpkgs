{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../profiles/personal.nix
    ../hardware/dell.nix
  ];
  machines.base.nixosState = "25.11";
  machines.base.wifiInterfaceName = "wlp0s13f0u1u4";
  machines.base.acceptRemoteBuilds = true;
  # Host-specific capabilities override the personal profile's explicit choices.
  machines.features.gpu.enable = lib.mkForce true;
  machines.features.notebooks.enable = lib.mkForce true;
  machines.features.imageGeneration.enable = lib.mkForce true;
  machines.features.localLlm.enable = lib.mkForce true;
  machines.localLlm = {
    acceleration = "cuda";
    extraModels = [ "huihui_ai/qwen3-vl-abliterated:8b-instruct" ];
  };
  services.comfyui.lowMem = true;
  services.bitd.checks = [
    "cozy_imgedit2"
    "cozy_video"
  ];
  # 4 GB RTX 500: leave room for Qwen-Image 2.1's sampling scratch buffers.
  services.comfyui.reserveVram = 1.0;
  services.comfyui.cozy.workflows = [
    "imggen"
    "imggen2"
    "imggen21"
    "imgedit2"
    "imgedit3"
    "imgedit4"
    "imgedit5"
  ];
  # Workflow <name>.api.json files live only on disk in services.comfyui.dataDir;
  # anixpkgs names them above but never defines or installs them.
  # imgedit4/imgedit5 need flux2_dev_turbo_fp8mixed.safetensors: the Flux.2 Turbo
  # LoRA baked offline into flux2_dev_fp8mixed by dataDir/tools/merge_flux2_lora.py
  # (also on disk only), since applying it at runtime OOMs the 4 GB card. imgedit5
  # runs at 2 MP through the FluxTokenChunking custom node, which chunks each Flux
  # block over tokens so its activations fit.
  systemd.services.comfyui.serviceConfig.ExecStartPre =
    "${pkgs.coreutils}/bin/install -D -m 0644 ${./comfyui-nodes/flux_token_chunking/__init__.py} /data/andrew/comfyui/custom_nodes/flux_token_chunking/__init__.py";
  networking.hostName = "atorgesen-dell";
}
