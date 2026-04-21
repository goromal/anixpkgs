{
  pkgs,
  config,
  lib,
  ...
}:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
  claudeCodeVersion = "2.1.116";
  claudeCodeExt =
    let
      base = builtins.head (
        unstable.vscode-utils.extensionsFromVscodeMarketplace [
          {
            name = "claude-code";
            publisher = "anthropic";
            version = claudeCodeVersion;
            sha256 = "sha256-47LEeYQGaeZiU+W+KGDi1g5OcTqDl/H4hW3TjeBMBbY=";
          }
        ]
      );
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = "vscode-extension-anthropic-claude-code-${claudeCodeVersion}-nixos";
      version = claudeCodeVersion;
      dontUnpack = true;
      dontBuild = true;
      installPhase = ''
        cp -r ${base} $out
        chmod -R u+w $out
        mkdir -p $out/share/vscode/extensions/anthropic.claude-code/resources/native-binaries/linux-x64
        ln -s ${anixpkgs.claude-code-bin}/bin/claude \
          $out/share/vscode/extensions/anthropic.claude-code/resources/native-binaries/linux-x64/claude
      '';
      passthru = {
        vscodeExtUniqueId = base.vscodeExtUniqueId;
        vscodeExtPublisher = base.vscodeExtPublisher;
        vscodeExtName = base.vscodeExtName;
      };
    };
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
        with unstable.vscode-extensions;
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
          claudeCodeExt
        ]
        ++ unstable.vscode-utils.extensionsFromVscodeMarketplace [
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
            name = "protobuf-vsc";
            publisher = "DrBlury";
            version = "1.0.1";
            sha256 = "sha256-DFLm0efm7krqcObblbgAlO9PsEGDtw9vrsIDeCtjd14=s";
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
