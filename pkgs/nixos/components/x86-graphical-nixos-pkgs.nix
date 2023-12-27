{ pkgs, config, lib, ... }:
with pkgs;
with import ../dependencies.nix { inherit config; };
let
  browser-aliases = (anixpkgs.callPackage ../../bash-packages/browser-aliases {
    browserExec = "${unstable.google-chrome}/bin/google-chrome-stable";
  });
in {
  imports =
    [ ./x86-graphical-pkgs.nix ../../bash-packages/nix-tools/module.nix ];

  home.packages = [
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
    browser-aliases
  ];

  programs.anix-tools = {
    enable = true;
    inherit anixpkgs;
    inherit browser-aliases;
  };

  gtk = {
    enable = true;
    iconTheme = {
      name = "Nordzy";
      package = nordzy-icon-theme;
    };
    theme = {
      name = "Nordic";
      package = nordic;
    };
  };

  dconf.settings = {
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
  };

  home.file = with anixpkgs.pkgData; {
    ".face".source = img.ajt-logo-white.data;
    ".config/gtk-4.0/${themes.nordic-gtk4.css.name}".source =
      themes.nordic-gtk4.css.data;
    ".config/gtk-4.0/${themes.nordic-gtk4.css-dark.name}".source =
      themes.nordic-gtk4.css-dark.data;
    ".config/gtk-4.0/${themes.nordic-gtk4.thumbnail.name}".source =
      themes.nordic-gtk4.thumbnail.data;
  };
}
