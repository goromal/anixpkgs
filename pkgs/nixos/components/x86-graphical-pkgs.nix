{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let cfg = config.mods.x86-graphical;
in {
  options.mods.x86-graphical = {
    standalone = lib.mkOption {
      type = lib.types.bool;
      description =
        "Whether this is a standalone Nix installation (default: false)";
      default = false;
    };
    homeDir = lib.mkOption {
      type = lib.types.str;
      description =
        "Home directory to put the wallpaper in (default: /data/andrew)";
      default = "/data/andrew";
    };
    vscodium-package = lib.mkOption {
      type = lib.types.package;
      description = "VSCode flavor to use (default: pkgs.vscodium)";
      default = vscodium;
    };
  };

  config = {
    dconf.settings = {
      "org/gnome/desktop/background" = {
        "picture-uri" = "${cfg.homeDir}/.background-image";
      };
      "org/gnome/desktop/screensaver" = {
        "picture-uri" = "${cfg.homeDir}/.background-image";
      };
    };

    # TODO the TK_LIBRARY hack should only be necessary until we move on from 23.05;
    # see https://github.com/NixOS/nixpkgs/issues/234962
    home.sessionVariables = {
      TK_LIBRARY = "${pkgs.tk}/lib/${pkgs.tk.libPrefix}";
    };

    home.packages = [
      black
      clang-tools
      terminator
      anixpkgs.authm
      anixpkgs.goromail
      anixpkgs.manage-gmail
      anixpkgs.gmail-parser
      anixpkgs.wiki-tools
      anixpkgs.book-notes-sync
      anixpkgs.budget_report
      anixpkgs.gantter
      anixpkgs.md2pdf
      anixpkgs.notabilify
      anixpkgs.code2pdf
      anixpkgs.abc
      anixpkgs.doku
      anixpkgs.epub
      anixpkgs.gif
      anixpkgs.md
      anixpkgs.mp3
      anixpkgs.mp4
      anixpkgs.mp4unite
      anixpkgs.pdf
      anixpkgs.png
      anixpkgs.svg
      anixpkgs.zipper
      anixpkgs.scrape
    ];

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
      "records/${records.crypt.name}".source = records.crypt.data;
      ".config/terminator/config".source =
        ../res/terminator-config; # https://rigel.netlify.app/#terminal
      "Templates/EmptyDocument".text = "";
      ".config/VSCodium/User/settings.json".source =
        ../res/vscode-settings.json;
      ".background-image".source = ((runCommand "make-wallpaper" { } ''
        mkdir $out
        ${imagemagick}/bin/convert -font ${fonts.nexa.data} \
           -pointsize 30 \
           -fill black \
           -draw 'text 320,1343 "${
             if local-build then "Local Build" else "v${anix-version}"
           } - ${
             if cfg.standalone then "Home-Manager" else "NixOS"
           } ${nixos-version}"' \
           ${img.wallpaper.data} $out/wallpaper.png
      '') + "/wallpaper.png");
    };
  };
}
