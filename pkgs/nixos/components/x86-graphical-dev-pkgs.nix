{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
in
{
  home.packages = [
    pkgs.black
    pkgs.clang-tools
    pkgs.nodejs
    anixpkgs.aptest
  ];

  dconf.settings = lib.mkIf (cfg.standalone == false) {
    "org/gnome/shell" = {
      "favorite-apps" = [ "code.desktop" ];
    };
  };

  # e.g., https://search.nixos.org/packages?channel=[NIXOS_VERSION]&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    profiles.default = {
      userSettings = {
        "editor.minimap.enabled" = false;
        "window.zoomLevel" = -1;
        "workbench.startupEditor" = "none";
        "security.workspace.trust.untrustedFiles" = "open";
        "editor.formatOnSave" = true;
        "files.hotExit" = "off";
        "C_Cpp.default.compilerPath" = "clang";
        "terminal.integrated.env.linux" = {
          "TMPDIR" = "/tmp";
        };
      };
      extensions =
        with pkgs.vscode-extensions;
        [
          eamodio.gitlens
          ms-python.vscode-pylance
          rust-lang.rust-analyzer
          jnoortheen.nix-ide
          yzhang.markdown-all-in-one
          xaver.clang-format
          ms-python.python
          valentjn.vscode-ltex
          b4dm4n.vscode-nixpkgs-fmt
          ms-vscode.cpptools
        ]
        ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "cmake";
            publisher = "twxs";
            version = "0.0.17";
            sha256 = "11hzjd0gxkq37689rrr2aszxng5l9fwpgs9nnglq3zhfa1msyn08";
          }
          {
            name = "vscode-rustfmt";
            publisher = "statiolake";
            version = "0.4.0";
            sha256 = "sha256-/GcL6Heah6cT5+6W6DQjlh3Zp0SEhk2fRaxoNYvi7Ks=";
          }
          {
            name = "protobuf-vsc";
            publisher = "DrBlury";
            version = "1.6.15";
            sha256 = "sha256-KWWjDiINAJljQnKzwqyJMZc6ZCOx4/Wq+4fNAn0v2CI=";
          }
        ];
    };
    mutableExtensionsDir = false;
  };

  home.file = with anixpkgs.pkgData; {
    ".config/gtk-3.0/bookmarks".text = ''
      file://${cfg.homeDir}/dev Development
      file://${cfg.homeDir}/data Data
      file://${cfg.homeDir}/Documents Documents
      file://${cfg.homeDir}/Downloads Downloads
    '';
  };
}
