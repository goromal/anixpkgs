{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let cfg = config.mods.opts;
in {
  home.packages = [ pkgs.black pkgs.clang-tools anixpkgs.aptest ];

  dconf.settings = lib.mkIf (cfg.standalone == false) {
    "org/gnome/shell" = { "favorite-apps" = [ "code.desktop" ]; };
  };

  # e.g., https://search.nixos.org/packages?channel=[NIXOS_VERSION]&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
  programs.vscode = {
    enable = true;
    package = unstable.vscode;
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
    profiles.default.extensions = with unstable.vscode-extensions;
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
        zxh404.vscode-proto3
        ms-vscode.cpptools
        anthropic.claude-code
      ] ++ unstable.vscode-utils.extensionsFromVscodeMarketplace [
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
      ];
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
