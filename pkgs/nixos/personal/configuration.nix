{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
    ##################################################################
    orig-nixos-version = "22.05"; # Should match system.stateVersion 
                                  # of original config
    nixos-version = "22.05"; # Should match the channel in <nixpkgs>
    anix-version  = "0.0.0"; # Whatever you want
    hardware-config = null; # e.g., ./hardware-configuration.nix
    ##################################################################
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz";
    anixpkgs     = import (builtins.fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/tags/v${anix-version}.tar.gz") {};
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

        home.packages = [
            ## upstream
            gnome3.gnome-tweaks
            vlc
            evince
            inkscape
            # dropbox # TODO configure
            vscodium
            chromium
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
            # texlive.combined.scheme-full TODO enable, add vscodium plugin
            docker
            ## my packages
            anixpkgs.color-prints
            anixpkgs.git-cc
            anixpkgs.md2pdf
            anixpkgs.notabilify
            anixpkgs.make-title
            anixpkgs.pb
            anixpkgs.cod2pdf
            anixpkgs.abc
            anixpkgs.doku
            anixpkgs.epub
            anixpkgs.gif
            anixpkgs.html
            anixpkgs.md
            anixpkgs.mp3
            anixpkgs.mp4
            anixpkgs.pdf
            anixpkgs.png
            anixpkgs.svg
            anixpkgs.zipper
            anixpkgs.fix-perms
            anixpkgs.secure-delete
            anixpkgs.sunnyside
            anixpkgs.scrape
            anixpkgs.flask-url2mp4
            anixpkgs.flask-mp4server
            anixpkgs.flask-mp3server
            anixpkgs.flask-smfserver
            anixpkgs.manage-gmail
        ];

        # TODO vscodium default settings

        # TODO add text file creation to context menu

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

        systemd.user.services.dropbox = {
            Unit = {
                Description = "Dropbox";
                After = [ "graphical-session-pre.target" ];
                PartOf = [ "graphical-session.target" ];
            };
            Service = {
                Restart = "on-failure";
                RestartSec = 1;
                ExecStart = "${dropbox}/bin/dropbox";
                Environment = "QT_PLUGIN_PATH=/run/current-system/sw/${qt5.qtbase.qtPluginPrefix}";
            };
            Install = {
                WantedBy = [ "graphical-session.target" ];
            };
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
