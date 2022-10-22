{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
    ##################################################################
    orig-nixos-version = "22.05"; # Should match system.stateVersion 
                                  # of original config
    nixos-version = "22.05"; # Should match the channel in <nixpkgs>
    anix-version  = "0.1.0"; # Whatever you want
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
                name = "Numix-Circle";
                package = pkgs.numix-icon-theme-circle;
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
                    "terminator.desktop"
                    "codium.desktop"
                    "pinta.desktop"
                    "gimp.desktop"
                    "org.inkscape.Inkscape.desktop"
                ];
            };
        };

        home.packages = [
            ## upstream
            gnome3.gnome-tweaks
            vlc
            evince
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
            ".config/terminator/config" = {
                text = ''
                [global_config]
                [keybindings]
                [profiles]
                [[default]]
                    background_color = "#002b36"
                    cursor_color = "#aaaaaa"
                    foreground_color = "#839496"
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
