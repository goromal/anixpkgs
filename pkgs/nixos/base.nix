{ config, pkgs, lib, ... }:
with pkgs;
with lib;
with import ./dependencies.nix { inherit config; };
let
    nixos-version = "22.05"; # Should match the channel in <nixpkgs>
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz";
in
{
    imports = [
        (import "${home-manager}/nixos")
    ];

    boot.kernelPackages = pkgs.linuxPackages_latest;
    boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.ipv4.tcp_notsent_lowat" = "16384";
        "net.ipv4.tcp_low_latency" = "1";
        "net.ipv4.tcp_slow_start_after_idle" = "0";
        "net.ipv4.tcp_mtu_probing" = "1";
        "net.ipv4.conf.all.forwarding" = "1";
        "net.ipv4.conf.default.forwarding" = "1";
    };

    nix.nixPath = [
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "anixpkgs=/data/andrew/sources/anixpkgs"
    ];

    nix.autoOptimiseStore = true;
    nix.buildCores = 4;
    nix.binaryCaches = [
        "https://cache.nixos.org/"
        "https://github-public.cachix.org"
        "https://ros.cachix.org"
    ];
    nix.binaryCachePublicKeys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
        "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
    ];
    nix.extraOptions = ''
        narinfo-cache-positive-ttl = 0
        narinfo-cache-negative-ttl = 0
        experimental-features = nix-command flakes
    '';
    nix.maxJobs = 4;
    nixpkgs.config.allowUnfree = true;

    # Use the systemd-boot EFI boot loader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # Set your time zone.
    time.timeZone = "America/Los_Angeles";

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    networking.useDHCP = false;
    networking.networkmanager.enable = true;

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
        font = "Lat2-Terminus16";
        keyMap = "us";
    };

    # Enable the OpenSSH daemon.
    services.openssh = {
        enable = true;
        forwardX11 = true;
    };
    programs.ssh.startAgent = true;
    
    programs.vim.defaultEditor = true;
    
    services.journald = {
        rateLimitBurst = 0;
        rateLimitInterval = "0s";
    };

    environment.systemPackages = [
        ack
        gcc
        gdb
        git
        gnumake
        cmake
        direnv
        valgrind
        iotop
        iperf
        python3
        htop
        jq
        libpwquality
        libinput
        lsof
        coreutils
        clang
        clang-tools
        neofetch
        onefetch
        man-pages
        black
        mosh
        nethogs
        tcpdump
        gparted
        tmux
        traceroute
        fish
        screen
        minicom
        dhcpcd
        dnsutils
        v4l_utils
        usbutils
        ffmpeg
        chrony
        unzip
        wget
        ethtool
        arp-scan
        dtc
        ncdu
        nmap
        # https://github.com/utdemir/nix-tree
        (writeShellScriptBin "nix-deps" ''
        if [[ $# -ge 2 ]]; then
            nix-build $@ --no-out-link | xargs -o ${nix-tree}/bin/nix-tree
        elif [[ $# -eq 1 ]]; then
            ${nix-tree}/bin/nix-tree "$1"
        else
            ${anixpkgs.color-prints}/bin/echo_red "Must specify either a store path or nix-build rules."
        fi
        '')
        (writeShellScriptBin "anix-version" ''echo "$(nix-store -q /nix/var/nix/profiles/system | cut -c 12-) (${if local-build then "Local Build" else "v${anix-version}"})"'')
    ];

    programs.bash.interactiveShellInit = ''eval "$(direnv hook bash)"'';

    environment.shellAliases = {
        jfu = "journalctl -fu";
        nrs = "sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild switch";
        nrb = "sudo NIXPKGS_ALLOW_UNFREE=1 nixos-rebuild boot";
        code = "codium";
    };
    environment.noXlibs = false;

    systemd.tmpfiles.rules = [
        "d /data 0777 root root"
    ];

    users.groups.dev = {
        gid = 1000;
    };
    users.users.andrew = {
        isNormalUser = true;
        uid = 1000;
        home = "/data/andrew";
        createHome = true;
        description = "Andrew Torgesen";
        group = "dev";
        extraGroups = [ "users" "wheel" "networkmanager" "dialout" "video" "docker" "systemd-journal" "wireshark" ];
        subUidRanges = [ { count = 1; startUid = 1000; } { count = 65536; startUid = 100000; } ];
        subGidRanges = [ { count = 1; startGid = 100; } { count = 65536; startGid = 100000; } ];
        hashedPassword = "$6$0fv.6VfJi8qfOLtZ$nJ9OeiLzDenXaogPJl1bIe6ipx4KTnsyPExB.9sZk/dEXfFv34PtRRxZf28RKwrpcg5bgmee6QiQFGQQhv4rS/";
        openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDARsquoLlZN+DIsqoBh1tQ4h5E+V1UD7SpBZCpzcWMHY+N8SJ6CnYKUiQU8FSCWSOhdZ1r52za+iMl0g983S71cH70attk5KvQYHYGfqpSckwIQ326wE6e+fPQAytgqv6CS+xjNzcpRwVRzBmlB1IyqNCl79OnWsg0TXxL/GBt3UUI9p6XjAeZhxpqb2NPZYHV+TZPPvI3/1X0LadBZZWFPbtoI+XbHABtW06YUDpR+BQSpFGtq+2eIjRgoo4WEHPewV73zzLVIYZ3xaa0Whmm4qTPpNtw+U1tHZkxUAjU92Y7Mq7oehd5z6YGRQ+UxSAuSYkR7xTt63KFb/vTjJg0W0LphwPYnfzG1M+jhK/6rGAdL0AYaUiMDTwl6gSkROKAzab63wf9gbeo+6Smgv3LQYCXvAFccEKtqlt1RLP/SUdTCdjVL728c0+WohrOD3tyRR8XU94CdOyLrhRG0k4Bcb0W0GYaLxsUSkc/wSyg6An9ITldBfH0FOON2sft52M= andrew@andrew-Precision-5550"
        ];
    };
    users.mutableUsers = true;

    programs.wireshark.enable = true;

    home-manager.users.andrew = {
        programs.home-manager.enable = true;

        home.packages = [
            anixpkgs.color-prints
            anixpkgs.git-cc
            anixpkgs.fix-perms
            anixpkgs.secure-delete
            anixpkgs.sunnyside
            anixpkgs.setupws
            anixpkgs.listsources
            anixpkgs.pkgshell
            anixpkgs.devshell
            anixpkgs.cpp-helper
            anixpkgs.py-helper
            anixpkgs.makepyshell
            anixpkgs.wiki-tools
            anixpkgs.book-notes-sync
            anixpkgs.providence
            anixpkgs.make-title
            anixpkgs.pb
            anixpkgs.manage-gmail
            anixpkgs.dirgroups
        ];

        programs.git = {
            package = gitAndTools.gitFull;
            enable = true;
            userName = "Andrew Torgesen";
            userEmail = "andrew.torgesen@gmail.com";
            aliases = {
                aa = "add -A";
                cm = "commit -m";
                co = "checkout";
                s = "status";
                d = "diff";
            };
            extraConfig = {
                init = {
                    defaultBranch = "master";
                };
                push = {
                    default = "current";
                };
                pull = {
                    default = "current";
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
        };
    };
}
