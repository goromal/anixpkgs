{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; }; {
  home.packages = [
    (writeShellScriptBin "launch-services" ''
    
    '')
  ];

  home.file = {
    "ats-modules/default.nix".source = ./ats-standalone-modules.nix;
    "flake.nix".text = ''
    {
      inputs = {
        nixpkgs.url = "github:goromal/anixpkgs?ref=v${anix-version}";

        system-manager = {
          url = "github:numtide/system-manager?rev=70490c9d59327ffbc58a40fd226ff48b73b697ee";
          inputs.nixpkgs.follows = "nixpkgs";
        };
      };

      outputs = { self, flake-utils, nixpkgs, system-manager }: {
        systemConfigs.default = system-manager.lib.makeSystemConfig {
          modules = [
            ./ats-modules
          ];
        };
      };
    }
    '';
  };
}
