{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let flakeFile = writeTextFile {
  name = "flake.nix";
  text = ''
  {
      inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs?ref=refs/tags/${nixos-version}";

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
in {
  home.packages = [
    (writeShellScriptBin "launch-services" ''
    cd $HOME
    echo "Setting up"
    if [[ -f flake.nix ]]; then
      rm flake.nix
    fi
    if [[ -d ats-modules ]]; then
      rm -r ats-modules
    fi
    cp ${flakeFile} flake.nix
    mkdir ats-modules
    cp ${./ats-standalone-modules.nix} ats-modules/default.nix
    echo "Running system-manager"
    nix run 'github:numtide/system-manager' -- switch --flake '.'
    '')
  ];
}
