{ pkgs, config, lib, ... }:
let cfg = config.mods.vscodium;
in with pkgs; {
  options.mods.vscodium = {
    package = lib.mkOption {
      type = lib.types.package;
      description = "VSCode flavor to use (default: pkgs.vscodium)";
      default = vscodium;
    };
  };

  config = {
    home.packages = [ clang-tools black ];

    # e.g., https://search.nixos.org/packages?channel=23.05&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
    programs.vscode = {
      enable = true;
      package = cfg.package;
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

    home.file = {
      ".config/VSCodium/User/settings.json".source =
        ../res/vscode-settings.json;
    };
  };
}
