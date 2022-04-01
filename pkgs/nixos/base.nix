{ config, pkgs, lib, ... }:
with pkgs;
with lib;
{
    imports = [
        ./kernel.nix
        #   <nixpkgs/nixos/modules/profiles/qemu-guest.nix>
    ];
    
    config = {
        environment.systemPackages = [
            # upstream
            ack
            gdb
            git
            iotop
            iperf
            htop
            jq
            libpwquality
            lsof
            manpages
            mosh
            nethogs
            python3
            tcpdump
            tmux
            traceroute
            tshark
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
            mosh
            ethtool
            arp-scan
            dtc
            # anixpkgs
            color-prints
        ];

        environment.shellAliases = {
            jfu = "journalctl -fu";
        };
        environment.noXlibs = false;

        console =
        {
            font = "cp437";
            keyMap = "us";
        };

        i18n.defaultLocale = "en_US.UTF-8";

        nix.autoOptimiseStore = true;
        nix.buildCores = 4;
        nix.binaryCaches = [
            "https://cache.nixos.org/"
            "https://github-public.cachix.org"
        ];
        nix.binaryCachePublicKeys = [
            "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
        ];
        nix.extraOptions = ''
            narinfo-cache-positive-ttl = 0
            narinfo-cache-negative-ttl = 0
        '';
        nix.maxJobs = 4;
        nix.nixPath = [ "nixpkgs=/data/andrew/sources/anixpkgs" ];

        services.timesyncd.enable = false;

        networking.firewall.enable = false;

        security.sudo = {
            enable = true;
            wheelNeedsPassword = true;

            extraConfig = ''
                # Log commands using sudo
                Defaults logfile="/var/log/sudo.log"

                # Passwords always prompted
                Defaults timestamp_timeout=0
            '';

            extraRules = [
                { 
                    groups = [ "wheel" ];
                    commands = [ { command = "ALL"; options = [ "SETENV" "PASSWD" ]; } ];
                }
            ];
        };

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
        users.mutableUsers = false;

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
    };
}
