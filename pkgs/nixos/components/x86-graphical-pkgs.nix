{ pkgs, config, lib, ... }:
with import ../dependencies.nix { inherit config; };
let
  cfg = config.mods.opts;
  browser-aliases = if cfg.browserExec == null then
    null
  else
    (anixpkgs.callPackage ../../bash-packages/browser-aliases {
      browserExec = cfg.browserExec;
    });
in {
  dconf.settings = ({
    "org/gnome/desktop/background" = {
      "picture-uri" = "${cfg.homeDir}/.background-image";
    };
    "org/gnome/desktop/screensaver" = {
      "picture-uri" = "${cfg.homeDir}/.background-image";
    };
  } // (if (cfg.standalone == false) then {
    "org/gnome/desktop/wm/preferences" = {
      "button-layout" = ":minimize,maximize,close";
    };
    "org/gnome/desktop/interface" = {
      "clock-format" = "12h";
      "clock-show-weekday" = true;
    };
    "org/gnome/desktop/privacy" = { "remember-recent-files" = false; };
    "org/gnome/shell" = {
      "favorite-apps" = [
        "org.gnome.Nautilus.desktop"
        "google-chrome.desktop"
        "terminator.desktop"
        "pinta.desktop"
        "gimp.desktop"
        "org.inkscape.Inkscape.desktop"
        "audacity.desktop"
        "blender.desktop"
      ];
      "enabled-extensions" = [ "Vitals@CoreCoding.com" ];
    };
    "org/gnome/shell/extensions/dash-to-dock" = {
      "dash-max-icon-size" = "16";
    };
    "org/gnome/desktop/peripherals/touchpad" = {
      "tap-to-click" = true;
      "two-finger-scrolling-enabled" = true;
    };
  } else
    { }));

  home.packages = with pkgs;
    [ terminator anixpkgs.getres ] ++ (if cfg.standalone == false then [
      kooha # wayland-compatible screen recorder
      gnome3.gnome-tweaks
      gnomeExtensions.vitals
      vlc
      evince
      calibre
      xclip
      graphviz
      gimp
      simplescreenrecorder
      pinta
      pandoc
      texlive.combined.scheme-full
      poppler_utils
      meld
      libreoffice-qt
      unstable.google-chrome
      unstable.inkscape
      unstable.audacity
      blender
    ] else
      [ ]) ++ (if browser-aliases != null then [ browser-aliases ] else [ ]);

  gtk = lib.mkIf (cfg.standalone == false) {
    enable = true;
    iconTheme = {
      name = "Nordzy";
      package = pkgs.nordzy-icon-theme;
    };
    theme = {
      name = "Nordic";
      package = pkgs.nordic;
    };
  };

  home.file = with anixpkgs.pkgData;
    ({
      ".config/terminator/config".source =
        ../res/terminator-config; # https://rigel.netlify.app/#terminal
      ".local/share/nautilus/scripts/terminal".source =
        (pkgs.writeShellScript "terminal" "terminator");
      ".config/nautilus/scripts-accels".text = "F4 terminal";
      "Templates/EmptyDocument".text = "";
      ".background-image".source = ((pkgs.runCommand "make-wallpaper" { } ''
        mkdir $out
        ${pkgs.imagemagick}/bin/convert -font ${fonts.nexa.data} \
           -pointsize 30 \
           -fill black \
           -draw 'text 320,1343 "${
             if local-build then "Local Build" else "v${anixpkgs-version}"
           } - ${
             if cfg.standalone then "Home-Manager" else "NixOS"
           } ${nixos-version}"' \
           -resize ${cfg.screenResolution}! \
           ${img.wallpaper.data} $out/wallpaper.png
      '') + "/wallpaper.png");
    } // (if (cfg.standalone == false) then {
      ".face".source = img.ajt-logo-white.data;
      ".config/gtk-4.0/${themes.nordic-gtk4.thumbnail.name}".source =
        themes.nordic-gtk4.thumbnail.data;
    } else
      { }));
}
