let
  pkgs = import ../default.nix { };
  sitlConfig = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    system = builtins.currentSystem;
    modules = [
      ../pkgs/cxx-packages/arducopter/sitl-module.nix
      {
        system.stateVersion = "25.11";
        services.ardupilot-sim = {
          enable = true;
          package = pkgs.hello;
          rootDir = "/tmp/ardusitl";
          user = "nobody";
          group = "nogroup";
          baseDefaultsFile = pkgs.writeText "base-params" ''
            FRAME_CLASS 1
          '';
        };
      }
    ];
  };
in
{
  documentation = pkgs.devshell.doc;
  sitl-with-generated-defaults = pkgs.runCommand "sitl-ifd-check" { } ''
    echo ${sitlConfig.config.systemd.services.ardusitl.serviceConfig.ExecStart} > $out
  '';
}
