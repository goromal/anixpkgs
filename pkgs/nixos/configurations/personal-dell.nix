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
  ];
  systemd.services.comfyui.serviceConfig.ExecStartPre =
    "${pkgs.coreutils}/bin/install -m 0644 ${./workflows/imggen21.api.json} /data/andrew/comfyui/imggen21.api.json";
  networking.hostName = "atorgesen-dell";
}
