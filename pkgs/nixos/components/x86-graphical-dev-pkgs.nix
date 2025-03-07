{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let cfg = config.mods.opts;
in {
  home.packages = [ pkgs.black pkgs.clang-tools anixpkgs.aptest ];

  dconf.settings = lib.mkIf (cfg.standalone == false) {
    "org/gnome/shell" = { "favorite-apps" = [ "codium.desktop" ]; };
  };

  # e.g., https://search.nixos.org/packages?channel=[NIXOS_VERSION]&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
  programs.vscode = {
    enable = true;
    package = unstable.vscodium;
    extensions = with pkgs.vscode-extensions;
      [
        eamodio.gitlens
        ms-python.vscode-pylance
        matklad.rust-analyzer
        jnoortheen.nix-ide
        yzhang.markdown-all-in-one
        xaver.clang-format
        ms-python.python
        valentjn.vscode-ltex
        b4dm4n.vscode-nixpkgs-fmt
        zxh404.vscode-proto3
        ms-vscode.cpptools
      ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
        {
          name = "cmake";
          publisher = "twxs";
          version = "0.0.17";
          sha256 = "11hzjd0gxkq37689rrr2aszxng5l9fwpgs9nnglq3zhfa1msyn08";
        }
        {
          name = "vscode-rustfmt";
          publisher = "statiolake";
          version = "0.1.2";
          sha256 = "0kprx45j63w1wr776q0cl2q3l7ra5ln8nwy9nnxhzfhillhqpipi";
        }
        {
          name = "claude-dev";
          publisher = "saoudrizwan";
          version = "3.3.1";
          sha256 = "sha256-9TltcgehgOi3kCYwSlYg6h2lhsEj0DmhrArf/eD59YM=";
        }
      ];
    mutableExtensionsDir = false;
  };

  home.file = with anixpkgs.pkgData; {
    ".config/VSCodium/User/settings.json".source = ../res/vscode-settings.json;
    ".config/gtk-3.0/bookmarks".text = ''
      file://${cfg.homeDir}/dev Development
      file://${cfg.homeDir}/data Data
    '';
  };
}
