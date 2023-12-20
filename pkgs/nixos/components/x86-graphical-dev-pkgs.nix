{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.x86-graphical;
in {
  options.mods.x86-graphical = {
    vscodium-package = lib.mkOption {
      type = lib.types.package;
      description = "VSCode flavor to use (default: pkgs.vscodium)";
      default = vscodium;
    };
  };

  config = {
    home.packages = [ black clang-tools ];

    # e.g., https://search.nixos.org/packages?channel=[NIXOS_VERSION]&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
    programs.vscode = {
      enable = true;
      package = cfg.vscodium-package;
      extensions = with vscode-extensions;
        [
          eamodio.gitlens
          ms-python.vscode-pylance
          matklad.rust-analyzer
          jnoortheen.nix-ide
          yzhang.markdown-all-in-one
          xaver.clang-format
          ms-python.python
          valentjn.vscode-ltex
          llvm-vs-code-extensions.vscode-clangd
          b4dm4n.vscode-nixpkgs-fmt
          zxh404.vscode-proto3
        ] ++ vscode-utils.extensionsFromVscodeMarketplace [
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
    };

    home.file = with anixpkgs.pkgData; {
      ".config/VSCodium/User/settings.json".source =
        ../res/vscode-settings.json;
    };
  };
}
