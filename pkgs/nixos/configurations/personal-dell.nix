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
  # imgedit4 is imgedit3 at 8 steps on flux2_dev_turbo_fp8mixed.safetensors: the
  # Flux.2 Turbo LoRA baked offline into flux2_dev_fp8mixed by
  # workflows/merge_flux2_lora.py (applying the LoRA at runtime OOMs the 4 GB
  # card, which requantizes each patched fp8 weight on the GPU). ~3.5x faster
  # than imgedit2 at matching quality.
  # imgedit5 is imgedit4 at 2 MP instead of 1 MP. Plain 1.5-2 MP OOMs the card on
  # transformer activations; the FluxTokenChunking custom node runs each block in
  # 4096-token chunks (bit-identical output, lower peak), landing at ~imgedit2's
  # runtime with twice the pixels.
  systemd.services.comfyui.serviceConfig.ExecStartPre =
    map
      (
        wf:
        "${pkgs.coreutils}/bin/install -m 0644 ${./workflows}/${wf}.api.json /data/andrew/comfyui/${wf}.api.json"
      )
      [
        "imggen21"
        "imgedit4"
        "imgedit5"
      ]
    ++ [
      "${pkgs.coreutils}/bin/install -D -m 0644 ${./comfyui-nodes/flux_token_chunking/__init__.py} /data/andrew/comfyui/custom_nodes/flux_token_chunking/__init__.py"
    ];
  networking.hostName = "atorgesen-dell";
}
