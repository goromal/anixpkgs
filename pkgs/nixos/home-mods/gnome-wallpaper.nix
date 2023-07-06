{ pkgs, config, lib, ... }:
let
    cfg = config.mods.gnome-wallpaper;
in with pkgs; with import ../dependencies.nix { inherit config; };
{
    options.mods.gnome-wallpaper = {
        standalone = lib.mkOption {
            type = lib.types.bool;
            description = "Whether this is a standalone Nix installation (default: false)";
            default = false;
        };
    };

    config = {
        dconf.settings = {
            "org/gnome/desktop/background" = {
                "picture-uri" = "/data/andrew/.background-image";
            };
            "org/gnome/desktop/screensaver" = {
                "picture-uri" = "/data/andrew/.background-image";
            };
        };

        home.file = with anixpkgs.pkgData; {
            ".background-image".source = ((runCommand "make-wallpaper" {} ''
                mkdir $out
                ${imagemagick}/bin/convert -font ${fonts.nexa.data} \
                   -pointsize 30 \
                   -fill black \
                   -draw 'text 320,1343 "${if local-build then "Local Build" else "v${anix-version}"} - ${if cfg.standalone then "Home-Manager" else "NixOS"} ${nixos-version}"' \
                   ${img.wallpaper.data} $out/wallpaper.png
            '') + "/wallpaper.png");
        };
    };
}
