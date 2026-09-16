{ config, lib, ... }:
let
  enableSunshine = config.machines.features.gameStreaming.enable;
in
{
  config = {
    services.sunset.enable = enableSunshine;
    # Sunshine's encoder test transiently binds port 48010, causing the RTSP
    # server to fail on the same port immediately after. The service exits 0
    # so on-failure won't retry — force always-restart so the second attempt
    # (port now free) succeeds automatically.
    systemd.user.services.sunshine = lib.mkIf enableSunshine {
      serviceConfig.Restart = lib.mkForce "always";
      serviceConfig.RestartSec = lib.mkForce "3s";
    };

    services.sunshine = lib.mkIf enableSunshine {
      enable = true;
      openFirewall = true;
      capSysAdmin = true;
      applications = {
        # Ensure play and rcrsync are reachable from the sunshine user service,
        # which runs with PATH=null per the NixOS sunshine module design.
        env.PATH = "$(HOME)/.nix-profile/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin";
        apps = [
          {
            name = "Zelda Collector's Edition";
            cmd = "play zelda";
          }
          {
            name = "Wind Waker";
            cmd = "play windwaker";
          }
          {
            name = "Twilight Princess";
            cmd = "play twilight";
          }
          {
            name = "Super Smash Bros. Melee";
            cmd = "play melee";
          }
          {
            name = "Super Mario Sunshine";
            cmd = "play sunshine";
          }
        ];
      };
    };
    services.udev.extraRules = lib.mkIf enableSunshine ''
      KERNEL=="uinput", GROUP="input", MODE="0660"
    '';

  };
}
