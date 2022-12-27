{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; };
{
    imports = [
        ../base.nix
    ];

    nix.nixPath = [
        "anixpkgs=/data/andrew/sources/anixpkgs"
    ];

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

    networking.firewall.allowedTCPPorts = [
        4444
    ];

    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
    services.xserver.desktopManager.gnome.enable = true;
    environment.gnome.excludePackages = [
        gnome-photos
        gnome-tour
    ] ++ (with gnome; [
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

    sound.enable = true;
    hardware.pulseaudio.enable = true;
    nixpkgs.config.pulseaudio = true;

    services.udev.packages = [ pkgs.dolphinEmu ];

    home-manager.users.andrew = {
        # nixpkgs/pkgs/data/themes
        # nixpkgs/pkgs/data/icons
        gtk = {
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
        dconf.settings = {
            "org/gnome/desktop/background" = {
                "picture-uri" = "/data/andrew/.background-image";
            };
            "org/gnome/desktop/screensaver" = {
                "picture-uri" = "/data/andrew/.background-image";
            };
            "org/gnome/desktop/wm/preferences" = {
                "button-layout" = ":minimize,maximize,close";
            };
            "org/gnome/desktop/interface" = {
                "clock-format" = "12h";
            };
            "org/gnome/desktop/privacy" = {
                "remember-recent-files" = false;
            };
            "org/gnome/shell" = {
                "favorite-apps" = [
                    "org.gnome.Nautilus.desktop"
                    "google-chrome.desktop"
                    "Alacritty.desktop"
                    "terminator.desktop"
                    "codium.desktop"
                    "pinta.desktop"
                    "gimp.desktop"
                    "org.inkscape.Inkscape.desktop"
                ];
                "enabled-extensions" = [
                    "Vitals@CoreCoding.com"
                ];
            };
            "org/gnome/shell/extensions/dash-to-dock" = {
                "dash-max-icon-size" = "16";
            };
        };

        home.packages = [
            ## upstream
            gnome3.gnome-tweaks
            gnomeExtensions.vitals
            vlc
            evince
            zathura
            inkscape
            maestral
            graphviz
            imagemagick
            terminator
            xclip
            gimp
            simplescreenrecorder
            pinta
            pandoc
            texlive.combined.scheme-full
            poppler_utils
            docker
            meld
            libreoffice-qt
            alacritty
            nixos-generators
            ## unstable
            unstable.google-chrome
            unstable.slack
            ## my packages
            anixpkgs.color-prints
            anixpkgs.cpp-helper
            anixpkgs.makepyshell
            anixpkgs.git-cc
            anixpkgs.md2pdf
            anixpkgs.notabilify
            anixpkgs.make-title
            anixpkgs.pb
            anixpkgs.code2pdf
            anixpkgs.abc
            anixpkgs.doku
            anixpkgs.epub
            anixpkgs.gif
            anixpkgs.html
            anixpkgs.md
            anixpkgs.mp3
            anixpkgs.mp4
            anixpkgs.mp4unite
            anixpkgs.pdf
            anixpkgs.png
            anixpkgs.svg
            anixpkgs.zipper
            anixpkgs.fix-perms
            anixpkgs.secure-delete
            anixpkgs.sunnyside
            anixpkgs.scrape
            anixpkgs.trafficsim
            anixpkgs.manage-gmail
            (writeShellScriptBin "playzelda" ''
                ${dolphinEmu}/bin/dolphin-emu -a LLE -e /data/andrew/Dropbox/Games/LegendOfZeldaCollectorsEdition.iso
            '')
        ];

        # https://search.nixos.org/packages?channel=22.05&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
        programs.vscode = {
            enable = true;
            package = unstable.vscodium;
            extensions = with vscode-extensions; [
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
            ".background-image".source = ../res/wallpaper.jpg;
            ".face".source = ../res/ajt.png;
            "Templates/EmptyDocument".text = "";
            ".config/VSCodium/User/settings.json".source = ../res/vscode-settings.json;
            ".config/zathura/zathurarc".source = ../res/zathurarc;
            # https://rigel.netlify.app/#terminal
            ".config/terminator/config".source = ../res/terminator-config;
            ".config/alacritty/alacritty.yml".source = ../res/alacritty.yml;
        };
    }; 
}
