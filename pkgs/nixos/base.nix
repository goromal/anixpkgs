{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
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

    nix.autoOptimiseStore = true;
    nix.buildCores = 4;
    nix.binaryCaches = [
        "https://cache.nixos.org/"
        "https://github-public.cachix.org"
    ];
    nix.binaryCachePublicKeys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
    ];
    nix.extraOptions = ''
        narinfo-cache-positive-ttl = 0
        narinfo-cache-negative-ttl = 0
    '';
    nix.maxJobs = 4;
    nix.nixPath = [ "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos" ];
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
    networking.interfaces.eno1.useDHCP = true;
    networking.interfaces.wlp179s0.useDHCP = true;

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

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
        cmake
        valgrind
        iotop
        iperf
        python3
        htop
        jq
        libpwquality
        lsof
        coreutils
        clang
        clang-tools
        man-pages
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
    ];

    environment.shellAliases = {
        jfu = "journalctl -fu";
        nrs = "sudo nixos-rebuild switch";
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
        extraGroups = [ "users" "wheel" "networkmanager" "dialout" "video" "docker" "systemd-journal" ];
        subUidRanges = [ { count = 1; startUid = 1000; } { count = 65536; startUid = 100000; } ];
        subGidRanges = [ { count = 1; startGid = 100; } { count = 65536; startGid = 100000; } ];
        hashedPassword = "$6$0fv.6VfJi8qfOLtZ$nJ9OeiLzDenXaogPJl1bIe6ipx4KTnsyPExB.9sZk/dEXfFv34PtRRxZf28RKwrpcg5bgmee6QiQFGQQhv4rS/";
        openssh.authorizedKeys.keys = [
            "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDARsquoLlZN+DIsqoBh1tQ4h5E+V1UD7SpBZCpzcWMHY+N8SJ6CnYKUiQU8FSCWSOhdZ1r52za+iMl0g983S71cH70attk5KvQYHYGfqpSckwIQ326wE6e+fPQAytgqv6CS+xjNzcpRwVRzBmlB1IyqNCl79OnWsg0TXxL/GBt3UUI9p6XjAeZhxpqb2NPZYHV+TZPPvI3/1X0LadBZZWFPbtoI+XbHABtW06YUDpR+BQSpFGtq+2eIjRgoo4WEHPewV73zzLVIYZ3xaa0Whmm4qTPpNtw+U1tHZkxUAjU92Y7Mq7oehd5z6YGRQ+UxSAuSYkR7xTt63KFb/vTjJg0W0LphwPYnfzG1M+jhK/6rGAdL0AYaUiMDTwl6gSkROKAzab63wf9gbeo+6Smgv3LQYCXvAFccEKtqlt1RLP/SUdTCdjVL728c0+WohrOD3tyRR8XU94CdOyLrhRG0k4Bcb0W0GYaLxsUSkc/wSyg6An9ITldBfH0FOON2sft52M= andrew@andrew-Precision-5550"
        ];
    };
    users.mutableUsers = true;
}
