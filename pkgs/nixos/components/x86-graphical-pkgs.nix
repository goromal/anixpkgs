{ pkgs, config, lib, ... }:
with import ../dependencies.nix;
let
  cfg = config.mods.opts;
  browser-aliases = if cfg.browserExec == null then
    null
  else
    (anixpkgs.callPackage ../../bash-packages/browser-aliases {
      browserExec = cfg.browserExec;
    });
  version-string = "anix - ${
      if local-build then "Local Build" else "v${anixpkgs-version}"
    } - ${if cfg.standalone then "Home-Manager" else "NixOS"} ${nixos-version}";
  wallpaper = pkgs.callPackage ../../bash-packages/mkWallpaper {
    pkgData = anixpkgs.pkgData;
    screenResolution = cfg.screenResolution;
    label = version-string;
    forcedImage = cfg.wallpaperImage;
  };
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
    "org/gnome/mutter" = { "dynamic-workspaces" = false; };
    "org/gnome/desktop/wm/preferences" = { "num-workspaces" = 1; };
  } else
    { }));

  home.packages = with pkgs;
    [ typora terminator anixpkgs.getres ] ++ (if cfg.standalone == false then [
      kooha # wayland-compatible screen recorder
      gnome-tweaks
      gnomeExtensions.vitals
      sqlitebrowser
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
      ".background-image".source = wallpaper;
    } // (if (cfg.standalone == false) then {
      ".face".source = img.ajt-logo-white.data;
      ".config/gtk-4.0/${themes.nordic-gtk4.thumbnail.name}".source =
        themes.nordic-gtk4.thumbnail.data;
    } else
      { }));
}
