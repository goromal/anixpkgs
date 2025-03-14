{ config, pkgs, lib, ... }:
with import ./dependencies.nix;
let
  cfg = config.machines.base;
  home-manager = builtins.fetchTarball
    "https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz";
in {
  options.machines.base = {
    homeDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory for primary user (default: /data/andrew)";
      default = "/data/andrew";
    };
    nixosState = lib.mkOption {
      type = lib.types.str;
      description = "Initiating state of the NixOS install (example: '22.05')";
    };
    machineType = lib.mkOption {
      type = lib.types.enum [ "x86_linux" "pi4" ];
      description = "Machine type that the closure is targeting.";
    };
    bootMntPt = lib.mkOption {
      type = lib.types.str;
      description =
        "(x86_linux) Boot partition mount point (default: /boot/efi)";
      default = "/boot/efi";
    };
    graphical = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the closure includes a graphical interface.";
    };
    recreational = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the closure includes recreational packages.";
    };
    developer = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the closure includes developer packages.";
    };
    loadATSServices = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the closure is for a personal server instance.";
    };
    serveNotesWiki = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to serve the notes wiki site.";
    };
    notesWikiPort = lib.mkOption {
      type = lib.types.int;
      description = "Public insecure port for the notes wiki site.";
      default = 80;
    };
    isInstaller = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the closure is for an ISO install image.";
    };
    enableMetrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to export OS metrics";
    };
    cloudDirs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description =
        "List of {name,cloudname,dirname} attributes defining the syncable directories by rcrsync";
      default = [
        {
          name = "configs";
          cloudname = "dropbox:configs";
          dirname = "$HOME/configs";
          autosync = true;
        }
        {
          name = "secrets";
          cloudname = "dropbox:secrets";
          dirname = "$HOME/secrets";
          autosync = false;
        }
        {
          name = "games";
          cloudname = "dropbox:games";
          dirname = "$HOME/games";
          autosync = true;
        }
        {
          name = "data";
          cloudname = "box:data";
          dirname = "$HOME/data";
          autosync = true;
        }
        {
          name = "documents";
          cloudname = "drive:Documents";
          dirname = "$HOME/Documents";
          autosync = true;
        }
      ];
    };
  };

  imports = [
    (import "${home-manager}/nixos")
    ../modules/ats/modules.nix
    ../modules/notes-wiki/module.nix
    ../modules/metricsNode/module.nix
  ];

  config = {
    system.stateVersion = cfg.nixosState;

    boot = {
      kernelPackages = (if cfg.machineType == "pi4" then
        pkgs.linuxPackages_rpi4
      else
        (if cfg.isInstaller then
          pkgs.linuxPackages_6_1
        else
          pkgs.linuxPackages_latest));
      kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
        "net.ipv4.tcp_notsent_lowat" = "16384";
        "net.ipv4.tcp_low_latency" = "1";
        "net.ipv4.tcp_slow_start_after_idle" = "0";
        "net.ipv4.tcp_mtu_probing" = "1";
        "net.ipv4.conf.all.forwarding" = "1";
        "net.ipv4.conf.default.forwarding" = "1";
      };
      loader = {
        # Use the systemd-boot EFI boot loader.
        # Grub is used on Raspberry Pi
        systemd-boot.enable =
          (if cfg.machineType == "x86_linux" then true else false);
        efi = {
          canTouchEfiVariables = true;
          efiSysMountPoint =
            lib.mkIf (cfg.machineType == "x86_linux") cfg.bootMntPt;
        };
      };
      supportedFilesystems =
        lib.mkIf (cfg.machineType == "x86_linux") [ "ntfs" ];
      binfmt.emulatedSystems =
        lib.mkIf (cfg.machineType == "x86_linux") [ "aarch64-linux" ];

      postBootCommands =
        lib.mkIf (cfg.machineType == "x86_linux" && cfg.graphical) (let
          gdm_user_conf = ''
            [User]
            Session=
            XSession=
            Icon=${cfg.homeDir}/.face
            SystemAccount=false
          '';
        in ''
          echo '${gdm_user_conf}' > /var/lib/AccountsService/users/andrew
        '');
    };

    # https://github.com/NixOS/nixpkgs/issues/154163
    nixpkgs.overlays = lib.mkIf (cfg.machineType == "pi4") [
      (final: super: {
        # modprobe: FATAL: Module sun4i-drm not found
        makeModulesClosure = x:
          super.makeModulesClosure (x // { allowMissing = true; });
      })
    ];

    nix = {
      nixPath = [
        "nixos-config=/etc/nixos/configuration.nix"
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "anixpkgs=${cfg.homeDir}/sources/anixpkgs"
      ];
      settings = {
        auto-optimise-store = true;
        max-jobs = 4;
        cores = 4;
        substituters =
          [ "https://cache.nixos.org/" "https://github-public.cachix.org" ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
        ];
      };
      extraOptions = ''
        narinfo-cache-positive-ttl = 0
        narinfo-cache-negative-ttl = 0
        experimental-features = nix-command flakes
      '';
    };

    services.xserver =
      lib.mkIf (cfg.machineType == "x86_linux" && cfg.graphical) {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
      };

    services.printing.enable =
      (cfg.machineType == "x86_linux" && cfg.graphical);
    services.avahi =
      lib.mkIf (cfg.machineType == "x86_linux" && cfg.graphical) {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };

    environment.gnome =
      lib.mkIf (cfg.machineType == "x86_linux" && cfg.graphical) {
        excludePackages = with pkgs;
          [ gnome-photos gnome-tour ] ++ (with gnome; [
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
      };

    # Specialized bluetooth and sound settings for Apple AirPods
    hardware.bluetooth = lib.mkIf
      (cfg.machineType == "x86_linux" && cfg.graphical && cfg.recreational) {
        enable = true;
        settings = { General = { ControllerMode = "bredr"; }; };
      };
    services.blueman.enable = lib.mkIf
      (cfg.machineType == "x86_linux" && cfg.graphical && cfg.recreational)
      true;
    hardware.pulseaudio.enable = lib.mkIf
      (cfg.machineType == "x86_linux" && cfg.graphical && cfg.recreational)
      false;
    security.rtkit.enable = lib.mkIf
      (cfg.machineType == "x86_linux" && cfg.graphical && cfg.recreational)
      true;
    services.pipewire = lib.mkIf
      (cfg.machineType == "x86_linux" && cfg.graphical && cfg.recreational) {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };

    services.udev.packages = lib.mkIf
      (cfg.machineType == "x86_linux" && cfg.graphical && cfg.recreational)
      [ pkgs.dolphinEmu ];

    # Set your time zone.
    time.timeZone = "America/Los_Angeles";

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    networking.useDHCP = false;
    networking.networkmanager.enable = !cfg.isInstaller;

    networking.firewall.allowedTCPPorts = [ 4444 ];

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us";
    };

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      settings = { X11Forwarding = true; };
    };
    programs.ssh.startAgent = true;

    programs.vim.defaultEditor = true;

    services.journald = {
      rateLimitBurst = 0;
      rateLimitInterval = "0s";
    };

    # Metrics
    services.metricsNode.enable = cfg.enableMetrics;
    services.metricsNode.openFirewall = cfg.enableMetrics;

    # Server processes
    services.ats.enable = cfg.loadATSServices;
    services.notes-wiki.enable = cfg.serveNotesWiki;
    services.notes-wiki.insecurePort = cfg.notesWikiPort;
    services.notes-wiki.openFirewall = true;

    # Global packages
    environment.systemPackages = with pkgs;
      [
        ack
        procs
        tldr
        fzf
        fdupes
        zoxide # z, ...
        duf
        gcc
        gdb
        tig
        scc
        most
        gnumake
        just
        hyperfine
        cmake
        valgrind
        iotop
        iperf
        iftop
        python3
        xsel
        htop
        jq
        libpwquality
        libinput
        rsync
        lsof
        mc
        coreutils
        ripgrep
        diff-so-fancy
        entr
        bat
        sd
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
        logkeys
        traceroute
        mtr
        fish
        screen
        minicom
        exiftool
        dhcpcd
        dnsutils
        v4l-utils
        usbutils
        ffmpeg
        chrony
        unzip
        wget
        aria2
        httpie
        ethtool
        arp-scan
        dtc
        ncdu
        nmap
        navi
        unstable.mprocs
        bandwhich
        btop
        glances
        gping
        dog
      ] ++ (if cfg.machineType == "pi4" then [ libraspberrypi ] else [ ]);

    programs.bash.interactiveShellInit = ''
      ${if cfg.developer then ''eval "$(direnv hook bash)"'' else ""}
    '';

    environment.shellAliases = {
      jfu = "journalctl -fu";
      code = "codium";
      nohistory = "set +o history";
    };
    environment.noXlibs = false;

    systemd.tmpfiles.rules = [ "d /data 0777 root root" ];

    users.groups.dev = { gid = 1000; };
    users.users.andrew = {
      isNormalUser = true;
      uid = 1000;
      home = cfg.homeDir;
      createHome = true;
      description = "Andrew Torgesen";
      group = "dev";
      extraGroups = [
        "users"
        "wheel"
        "networkmanager"
        "dialout"
        "video"
        "docker"
        "systemd-journal"
        "wireshark"
      ];
      subUidRanges = [
        {
          count = 1;
          startUid = 1000;
        }
        {
          count = 65536;
          startUid = 100000;
        }
      ];
      subGidRanges = [
        {
          count = 1;
          startGid = 100;
        }
        {
          count = 65536;
          startGid = 100000;
        }
      ];
      hashedPassword =
        "$6$0fv.6VfJi8qfOLtZ$nJ9OeiLzDenXaogPJl1bIe6ipx4KTnsyPExB.9sZk/dEXfFv34PtRRxZf28RKwrpcg5bgmee6QiQFGQQhv4rS/";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDARsquoLlZN+DIsqoBh1tQ4h5E+V1UD7SpBZCpzcWMHY+N8SJ6CnYKUiQU8FSCWSOhdZ1r52za+iMl0g983S71cH70attk5KvQYHYGfqpSckwIQ326wE6e+fPQAytgqv6CS+xjNzcpRwVRzBmlB1IyqNCl79OnWsg0TXxL/GBt3UUI9p6XjAeZhxpqb2NPZYHV+TZPPvI3/1X0LadBZZWFPbtoI+XbHABtW06YUDpR+BQSpFGtq+2eIjRgoo4WEHPewV73zzLVIYZ3xaa0Whmm4qTPpNtw+U1tHZkxUAjU92Y7Mq7oehd5z6YGRQ+UxSAuSYkR7xTt63KFb/vTjJg0W0LphwPYnfzG1M+jhK/6rGAdL0AYaUiMDTwl6gSkROKAzab63wf9gbeo+6Smgv3LQYCXvAFccEKtqlt1RLP/SUdTCdjVL728c0+WohrOD3tyRR8XU94CdOyLrhRG0k4Bcb0W0GYaLxsUSkc/wSyg6An9ITldBfH0FOON2sft52M= andrew@andrew-Precision-5550"
      ];
    };
    users.mutableUsers = true;

    programs.wireshark.enable = true;

    home-manager.users.andrew = {
      programs.home-manager.enable = true;
      programs.command-not-found.enable = true;

      imports = [ ./components/opts.nix ./components/base-pkgs.nix ]
        ++ (if cfg.developer then [ ./components/base-dev-pkgs.nix ] else [ ])
        ++ (if cfg.machineType == "pi4" then
          [ ./components/pi-pkgs.nix ]
        else
          [ ]) ++ (if cfg.machineType == "x86_linux" then
            ([ ./components/x86-pkgs.nix ] ++ (if cfg.recreational then
              [ ./components/x86-rec-pkgs.nix ]
            else
              [ ]) ++ (if cfg.graphical then
                ([ ./components/x86-graphical-pkgs.nix ]
                  ++ (if cfg.developer then
                    [ ./components/x86-graphical-dev-pkgs.nix ]
                  else
                    [ ]) ++ (if cfg.recreational then
                      [ ./components/x86-graphical-rec-pkgs.nix ]
                    else
                      [ ]))
              else
                [ ]))
          else
            [ ]);

      mods.opts = {
        homeState = cfg.nixosState;
        standalone = false;
        homeDir = cfg.homeDir;
        browserExec = if cfg.graphical && cfg.machineType == "x86_linux" then
          "${unstable.google-chrome}/bin/google-chrome-stable"
        else
          null;
        cloudDirs = cfg.cloudDirs;
        userOrchestrator = !cfg.loadATSServices;
        cloudAutoSync = false; # !cfg.loadATSServices;
        enableMetrics = cfg.enableMetrics;
      };
    };
  };
}
