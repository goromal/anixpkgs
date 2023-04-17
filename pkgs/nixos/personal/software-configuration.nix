{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ../dependencies.nix { inherit config; };
{
    imports = [
        ../base.nix
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

    services.lorri.enable = true;

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
            alacritty
            nixos-generators
            ## unstable
            unstable.google-chrome
            unstable.slack
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
            (writeShellScriptBin "playzelda" ''
                ${dolphinEmu}/bin/dolphin-emu -a LLE -e /data/andrew/Dropbox/Games/LegendOfZeldaCollectorsEdition.iso
            '')
            (anixpkgs.callPackage ../../bash-packages/browser-aliases {
                browserExec = "${unstable.google-chrome}/bin/google-chrome-stable";
            })
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

        home.file = with anixpkgs.pkgData; {
            ".background-image".source = ((runCommand "make-wallpaper" {} ''
                mkdir $out
                ${imagemagick}/bin/convert -font ${fonts.nexa.data} \
                   -pointsize 30 \
                   -fill black \
                   -draw 'text 320,1343 "${if local-build then "Local Build" else "v${anix-version}"}"' \
                   ${img.wallpaper.data} $out/wallpaper.png
            '') + "/wallpaper.png");
            ".face".source = img.ajt-logo-white.data;
            "Templates/EmptyDocument".text = "";
            ".config/VSCodium/User/settings.json".source = ../res/vscode-settings.json;
            ".config/zathura/zathurarc".source = ../res/zathurarc;
            ".config/terminator/config".source = ../res/terminator-config; # https://rigel.netlify.app/#terminal
            ".config/alacritty/alacritty.yml".source = ../res/alacritty.yml;
            "configs/${configs.book-notes.name}".source = configs.book-notes.data;
            "models/gender/${models.gender.proto.name}".source = models.gender.proto.data;
            "models/gender/${models.gender.weights.name}".source = models.gender.weights.data;
            "spleeter/pretrained_models/2stems/${models.spleeter.checkpoint.name}".source = models.spleeter.checkpoint.data;
            "spleeter/pretrained_models/2stems/${models.spleeter.model-data.name}".source = models.spleeter.model-data.data;
            "spleeter/pretrained_models/2stems/${models.spleeter.model-index.name}".source = models.spleeter.model-index.data;
            "spleeter/pretrained_models/2stems/${models.spleeter.model-meta.name}".source = models.spleeter.model-meta.data;
            "records/${records.crypt.name}".source = records.crypt.data;
        };
    }; 
}
