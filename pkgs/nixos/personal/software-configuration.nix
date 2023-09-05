{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; }; {
  imports = [ ../base.nix ];

  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.supportedFilesystems = [ "ntfs" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.postBootCommands = let
    gdm_user_conf = ''
      [User]
      Session=
      XSession=
      Icon=/data/andrew/.face
      SystemAccount=false
    '';
  in ''
    echo '${gdm_user_conf}' > /var/lib/AccountsService/users/andrew
  '';

  networking.firewall.allowedTCPPorts = [ 4444 ];

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;
  environment.gnome.excludePackages = [ gnome-photos gnome-tour ]
    ++ (with gnome; [
      cheese
      gnome-music
      epiphany
      geary
      evince
      totem
      tali
      iagno
      hitori
      atomix
    ]);

  # Specialized bluetooth and sound settings for Apple AirPods
  hardware.bluetooth.enable = true;
  hardware.bluetooth.settings = { General = { ControllerMode = "bredr"; }; };
  services.blueman.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  services.udev.packages = [ pkgs.dolphinEmu ];

  home-manager.users.andrew = {
    imports = [
      ../home-mods/vscodium.nix
      ../home-mods/terminator.nix
      # ../home-mods/zathura.nix
      ../home-mods/nautilus.nix
      ../home-mods/gnome-wallpaper.nix
      ../home-mods/zelda.nix
    ];

    mods.vscodium.package = unstable.vscodium;
    mods.playzelda.enable = true;

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
          "codium.desktop"
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

    home.packages = [
      ## upstream
      pavucontrol # compatible with pipewire-pulse
      kooha # wayland-compatible screen recorder
      gnome3.gnome-tweaks
      gnomeExtensions.vitals
      vlc
      evince
      calibre
      maestral
      graphviz
      imagemagick
      xclip
      pciutils
      gimp
      simplescreenrecorder
      pinta
      pandoc
      texlive.combined.scheme-full
      poppler_utils
      docker
      meld
      libreoffice-qt
      nixos-generators
      sage
      ## unstable
      unstable.google-chrome
      unstable.slack
      unstable.inkscape
      unstable.audacity
      # unstable.blender
      blender
      ## my packages
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
      anixpkgs.trafficsim
      anixpkgs.la-quiz
      anixpkgs.budget_report
      anixpkgs.fqt
      anixpkgs.authm
      anixpkgs.manage-gmail
      anixpkgs.wiki-tools
      anixpkgs.book-notes-sync
      anixpkgs.providence
      anixpkgs.providence-tasker
      anixpkgs.gantter
      (anixpkgs.callPackage ../../bash-packages/browser-aliases {
        browserExec = "${unstable.google-chrome}/bin/google-chrome-stable";
      })
      anixpkgs.mfn
    ];

    home.file = with anixpkgs.pkgData; {
      ".face".source = img.ajt-logo-white.data;
      "records/${records.crypt.name}".source = records.crypt.data;
      "configs/${configs.book-notes.name}".source = configs.book-notes.data;
      "models/gender/${models.gender.proto.name}".source =
        models.gender.proto.data;
      "models/gender/${models.gender.weights.name}".source =
        models.gender.weights.data;
      "spleeter/pretrained_models/2stems/${models.spleeter.checkpoint.name}".source =
        models.spleeter.checkpoint.data;
      "spleeter/pretrained_models/2stems/${models.spleeter.model-data.name}".source =
        models.spleeter.model-data.data;
      "spleeter/pretrained_models/2stems/${models.spleeter.model-index.name}".source =
        models.spleeter.model-index.data;
      "spleeter/pretrained_models/2stems/${models.spleeter.model-meta.name}".source =
        models.spleeter.model-meta.data;
      ".config/gtk-4.0/${themes.nordic-gtk4.css.name}".source =
        themes.nordic-gtk4.css.data;
      ".config/gtk-4.0/${themes.nordic-gtk4.css-dark.name}".source =
        themes.nordic-gtk4.css-dark.data;
      ".config/gtk-4.0/${themes.nordic-gtk4.thumbnail.name}".source =
        themes.nordic-gtk4.thumbnail.data;
    };
  };
}
