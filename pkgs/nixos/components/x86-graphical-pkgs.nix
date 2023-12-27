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

    home.packages = [ terminator anixpkgs.budget_report ];

    home.file = with anixpkgs.pkgData; {
      # TODO the TK_LIBRARY hack should only be necessary until we move on from 23.05;
      # see https://github.com/NixOS/nixpkgs/issues/234962
      "TK_LIB_VARS.sh".text = ''
        export TK_LIBRARY="${pkgs.tk}/lib/${pkgs.tk.libPrefix}"
      '';
      ".config/terminator/config".source =
        ../res/terminator-config; # https://rigel.netlify.app/#terminal
      ".local/share/nautilus/scripts/terminal".source =
        (writeShellScript "terminal" "terminator");
      ".config/nautilus/scripts-accels".text = "F4 terminal";
      "Templates/EmptyDocument".text = "";
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
