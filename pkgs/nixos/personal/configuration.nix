{ config, pkgs, lib, ... }:
with pkgs;
with lib;
let
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
    imports = [
        ../base.nix
        (import "${home-manager}/nixos")
    ];

    config = {
        networking.hostName = "personal";

        services.xserver.enable = true;
        services.xserver.desktopManager.gnome.enable = true;
        services.xserver.displayManager.gdm.enable = true;
        programs.ssh.setXAuthLocation = true;

        services.dbus.packages = [ dconf ];
        programs.dconf.enable = true;

        environment.gnome.excludePackages = [
            gnome.cheese
            gnome.gnome-music
            epiphany
            gnome.totem 
            gnome.tali 
            gnome.iagno 
            gnome.hitori 
            gnome.atomix 
            gnome-tour  
            gnome.geary 
        ];

        home-manager.users.andrew = {
            programs.home-manager.enable = true;

            gtk = { # TODO doesn't show up
                enable = true;
                theme = {
                    name = "Nordic";
                    package = nordic;
                };
            };

            home.packages = [
                vlc
                evince
                inkscape
                dropbox # TODO configure
                vscodium
                chromium
                google-chrome
                gnumake
                gcc
                gdb
                cmake
                valgrind
                graphviz
                imagemagick
                xclip
                gimp
                simplescreenrecorder
                pinta
                pandoc
                # texlive.combined.scheme-full TODO enable, add vscodium plugin
            ];

            # TODO vscodium default settings

            # TODO add text file creation to context menu

            programs.git = {
                package = gitAndTools.gitFull;
                enable = true;
                userName = "Andrew Torgesen";
                userEmail = "andrew.torgesen@gmail.com";
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
                    relativenumber = true;
                    number = true;
                };
                plugins = with vimPlugins; [
                    vim-elixir
                    # vim-mix-format
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
            };
        };
    };
}
