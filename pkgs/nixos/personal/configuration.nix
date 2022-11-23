{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
    ##################################################################
    orig-nixos-version = "22.05"; # Should match system.stateVersion 
                                  # of original config
    nixos-version = "22.05"; # Should match the channel in <nixpkgs>
    anix-version  = "0.2.0"; # Whatever you want
    hardware-config = ./hardware-configuration-inspiron.nix;
    ##################################################################
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz";
    anixpkgs     = import (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anix-version}.tar.gz") {
        config.allowUnfree = true;
    };
    play-zelda = writeShellScriptBin "playzelda" ''
        ${dolphinEmu}/bin/dolphin-emu -a LLE -e /data/andrew/Dropbox/Games/LegendOfZeldaCollectorsEdition.iso
    '';
in
{
    imports = [
        hardware-config
        ../base.nix
        (import "${home-manager}/nixos")
    ];

    nix.nixPath = lib.mkForce [
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "nixos-config=/data/andrew/sources/anixpkgs/pkgs/nixos/personal/configuration.nix"
        "anixpkgs=/data/andrew/sources/anixpkgs"
    ];

    networking.hostName = "atorgesen-laptop";
    boot.loader.efi.efiSysMountPoint = "/boot/efi";
    networking.networkmanager.enable = true;
    boot.supportedFilesystems = [ "ntfs" ];

    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # Configure keymap in X11
    # services.xserver.layout = "us";
    # services.xserver.xkbOptions = "eurosign:e";

    # Enable the GNOME Desktop Environment.
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

    # Enable CUPS to print documents.
    # services.printing.enable = true;

    sound.enable = true;
    hardware.pulseaudio.enable = true;
    nixpkgs.config.pulseaudio = true;

    services.udev.packages = [ pkgs.dolphinEmu ];

    home-manager.users.andrew = {
        programs.home-manager.enable = true;

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
            chromium
            maestral
            google-chrome
            direnv
            gnumake
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
            slack
            neofetch
            onefetch # git info for a local repo in terminal
            alacritty
            ## my packages
            anixpkgs.color-prints
            anixpkgs.git-cc
            anixpkgs.cpp-helper
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
            anixpkgs.manage-gmail
            play-zelda
        ];

        # https://search.nixos.org/packages?channel=22.05&from=0&size=50&sort=relevance&type=packages&query=vscode-extensions
        programs.vscode = {
            enable = true;
            package = vscodium;
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

        programs.git = {
            package = gitAndTools.gitFull;
            enable = true;
            userName = "Andrew Torgesen";
            userEmail = "andrew.torgesen@gmail.com";
            extraConfig = {
                init = {
                    defaultBranch = "master";
                };
            };
        };

        programs.command-not-found.enable = true;

        programs.vim = {
            enable = true;
            extraConfig = ''
                if has('gui_running')
                    set guifont=Iosevka
                endif
                set expandtab
                " open NERDTree automatically if no file specified
                "autocmd StdinReadPre * let s:std_in=1
                "autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
                " open NERDTree on Ctrl-n
                map <C-n> :NERDTreeToggle<CR>
                set wildignore+=*/node_modules/*,_site,*/__pycache__/,*/venv/*,*/target/*,*/.vim$,\~$,*/.log,*/.aux,*/.cls,*/.aux,*/.bbl,*/.blg,*/.fls,*/.fdb*/,*/.toc,*/.out,*/.glo,*/.log,*/.ist,*/.fdb_latexmk
                set encoding=utf-8
                set termguicolors
                set background=dark
                let g:mix_format_on_save = 1
                let g:mix_format_options = '--check-equivalent'
            '';
            settings = {
                number = true;
            };
            plugins = with vimPlugins; [
                vim-elixir
                sensible
                vim-airline
                The_NERD_tree
                fugitive
                vim-gitgutter
                YouCompleteMe
                vim-abolish
                command-t
            ];
        };

        home.file = {
            ".tmux.conf" = {
                text = ''
                    set-option -g default-shell /run/current-system/sw/bin/fish
                    set-window-option -g mode-keys vi
                    set -g default-terminal "screen-256color"
                    set -ga terminal-overrides ',screen-256color:Tc'
                '';
            };
            ".background-image" = {
                source = ../res/wallpaper.jpg;
            };
            "Templates/EmptyDocument" = {
                text = "";
            };
            ".config/VSCodium/User/settings.json" = {
                text = ''
                {
                    "editor.formatOnSave": true,
                    "editor.minimap.enabled": false,
                    "clang-format.language.cpp.enable": true,
                    "clang-format.executable": "/run/current-system/sw/bin/clang-format",
                    "clang-format.language.cpp.style": "",
                    "window.zoomLevel": -1,
                    "workbench.startupEditor": "none",
                    "security.workspace.trust.untrustedFiles": "open"
                }
                '';
            };
            ".config/zathura/zathurarc" = {
                text = ''
                # zathurarc-dark
                set notification-error-bg       "#586e75" # base01
                set notification-error-fg       "#dc322f" # red
                set notification-warning-bg     "#586e75" # base01
                set notification-warning-fg     "#dc322f" # red
                set notification-bg             "#586e75" # base01
                set notification-fg             "#b58900" # yellow

                set completion-group-bg         "#002b36" # base03
                set completion-group-fg         "#839496" # base0
                set completion-bg               "#073642" # base02
                set completion-fg               "#93a1a1" # base1
                set completion-highlight-bg     "#586e75" # base01
                set completion-highlight-fg     "#eee8d5" # base2

                # Define the color in index mode
                set index-bg                   "#073642" # base02
                set index-fg                   "#93a1a1" # base1
                set index-active-bg             "#586e75" # base01
                set index-active-fg             "#eee8d5" # base2

                set inputbar-bg                 "#586e75" # base01
                set inputbar-fg                 "#eee8d5" # base2

                set statusbar-bg                "#073642" # base02
                set statusbar-fg                "#93a1a1" # base1

                set highlight-color             "#657b83" # base00  # hightlight match when search keyword(vim's /)
                set highlight-active-color      "#268bd2" # blue

                set default-bg                  "#073642" # base02
                set default-fg                  "#93a1a1" # base1
                # set render-loading              true
                # set render-loading-fg           "#073642" # base02
                # set render-loading-bg           "#073642" # base02

                # Recolor book content's color
                set recolor                     true
                set recolor-lightcolor          "#073642" # base02
                set recolor-darkcolor           "#93a1a1" # base1
                # set recolor-keephue             true      # keep original color
                '';
            };
            # https://rigel.netlify.app/#terminal
            ".config/terminator/config" = {
                text = ''
                [global_config]
                [keybindings]
                [profiles]
                [[default]]
                    background_color = "#002635"
                    cursor_color = "#ffcc1b"
                    foreground_color = "#e6e6dc"
                    palette = "#073642:#dc322f:#859900:#b58900:#268bd2:#d33682:#2aa198:#eee8d5:#002b36:#cb4b16:#586e75:#657b83:#839496:#6c71c4:#93a1a1:#fdf6e3"
                [layouts]
                [[default]]
                    [[[window0]]]
                    type = Window
                    parent = ""
                    [[[child1]]]
                    type = Terminal
                    parent = window0
                [plugins]
                '';
            };
            ".config/alacritty/alacritty.yml" = {
                text = ''
                colors:
                    # Default colors
                    primary:
                        background: '0x002635'
                        foreground: '0xe6e6dc'

                    # Normal colors
                    normal:
                        black:   '0x00384d'
                        red:     '0xc43061'
                        green:   '0x7fc06e'
                        yellow:  '0xf08e48'
                        blue:    '0x1c8db2'
                        magenta: '0xc694ff'
                        cyan:    '0x00cccc'
                        white:   '0x77929e'

                    # Bright colors
                    bright:
                        black:   '0x517f8d'
                        red:     '0xff5a67'
                        green:   '0x9cf087'
                        yellow:  '0xffcc1b'
                        blue:    '0x7eb2dd'
                        magenta: '0xfb94ff'
                        cyan:    '0x00ffff'
                        white:   '0xb7cff9'

                    cursor:
                        text: "0x002635"
                        cursor: "0xffcc1b"
                '';
            };
        };
    };

    # Open ports in the firewall.
    # networking.firewall.allowedTCPPorts = [ ... ];
    # networking.firewall.allowedUDPPorts = [ ... ];
    # Or disable the firewall altogether.
    # networking.firewall.enable = false;

    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = orig-nixos-version; # Did you read the comment?    
}
