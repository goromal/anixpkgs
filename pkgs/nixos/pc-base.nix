{ config, pkgs, lib, ... }:
with import ./dependencies.nix;
let
  cfg = config.machines.base;
  home-manager = builtins.fetchTarball
    "https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz";
  atsudo = pkgs.writeShellScriptBin "atsudo" ''
    args=""
    for word in "$@"; do
      args+="$word "
    done
    args=''${args% }
    pw=$(${anixpkgs.sread}/bin/sread ${cfg.homeDir}/secrets/${config.networking.hostName}/p.txt.tyz)
    if [[ ! -z "$pw" ]]; then
      echo "$pw" | sudo -S $args
    else
      sudo $args
    fi
  '';
  machine-rcrsync = anixpkgs.rcrsync.override {
    homeDir = cfg.homeDir;
    cloudDirs = cfg.cloudDirs;
    rcloneCfg = "${cfg.homeDir}/.config/rclone/rclone.conf";
  };
  machine-authm = anixpkgs.authm.override { rcrsync = machine-rcrsync; };
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
      default = "/boot";
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
    isATS = lib.mkOption {
      type = lib.types.bool;
      description = "Whether the closure is for a personal server instance.";
    };
    runWebServer = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to spawn a reverse proxy webserver.";
      default = false;
    };
    webServerInsecurePort = lib.mkOption {
      type = lib.types.int;
      description = "Public insecure port";
      default = 80;
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
    enableMetrics = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to export OS metrics";
    };
    enableFileServers = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to turn on file servers";
    };
    cloudDirs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description =
        "List of {name,cloudname,dirname} attributes (dirname is relative to home) defining the syncable directories by rcrsync";
    };
    enableOrchestrator = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the orchestrator daemon";
    };
    timedOrchJobs = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      description = "Orchestrator job definitions";
      default = [ ];
    };
    extraOrchestratorPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Packages to add to orchestrator's path";
      default = [ ];
    };
  };

  imports = [
    (import "${home-manager}/nixos")
    ../modules/notes-wiki/module.nix
    ../modules/metricsNode/module.nix
    ../modules/plexNode/module.nix
    ../modules/mailNode/module.nix
    ../python-packages/orchestrator/module.nix
    ../python-packages/daily_tactical_server/module.nix
    ../python-packages/flasks/authui/module.nix
    ../python-packages/flasks/budget_ui/module.nix
    ../python-packages/flasks/rankserver/module.nix
    ../python-packages/flasks/stampserver/module.nix
  ];

  config = {
    system.stateVersion = cfg.nixosState;

    boot = {
      kernelPackages = (if cfg.machineType == "pi4" then
        pkgs.linuxPackages_rpi4
      else
        pkgs.linuxPackages_latest);
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

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
      # Web server DNS
      publish = lib.mkIf cfg.runWebServer {
        enable = true;
        addresses = true;
        domain = true;
        workstation = true;
      };
    };

    # Web server reverse proxy
    services.nginx = lib.mkIf cfg.runWebServer {
      enable = true;
      user = "andrew";
      group = "dev";
      virtualHosts."${config.networking.hostName}.local" = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.webServerInsecurePort;
        }];
      };
    };

    services.authui = {
      enable = cfg.isATS;
      initScript = (pkgs.writeShellScriptBin "atsauthui-start" ''
        ${pkgs.systemd}/bin/systemctl stop orchestratord
      '') + "/bin/atsauthui-start";
      resetScript = (pkgs.writeShellScriptBin "atsauthui-finish" ''
        ${machine-rcrsync}/bin/rcrsync override secrets
        ${pkgs.systemd}/bin/systemctl start orchestratord
      '') + "/bin/atsauthui-finish";
    };

    services.budget_ui = {
      enable = cfg.isATS;
      pathPkgs = [
        pkgs.bash
        pkgs.coreutils
        pkgs.util-linux
        pkgs.rclone
        machine-rcrsync
        machine-authm
        anixpkgs.budget_report
        anixpkgs.fixfname
      ];
    };

    services.rankserver = {
      enable = cfg.isATS || cfg.enableFileServers;
      package = anixpkgs.rankserver;
      rootDir = "${cfg.homeDir}/fileservers";
    };

    services.stampserver = {
      enable = cfg.isATS || cfg.enableFileServers;
      package = anixpkgs.stampserver;
      rootDir = "${cfg.homeDir}/fileservers";
    };

    environment.gnome =
      lib.mkIf (cfg.machineType == "x86_linux" && cfg.graphical) {
        excludePackages = with pkgs; [
          gnome-photos
          gnome-tour
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
        ];
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
    services.pulseaudio.enable = lib.mkIf
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
      [ pkgs.dolphin-emu ];

    # Set your time zone.
    time.timeZone = "America/Los_Angeles";

    # Orchestrator jobs
    services.orchestratord = lib.mkIf cfg.enableOrchestrator {
      enable = true;
      orchestratorPkg = anixpkgs.orchestrator;
      threads = 2;
      pathPkgs = with pkgs;
        [ bash coreutils util-linux rclone machine-rcrsync machine-authm ]
        ++ cfg.extraOrchestratorPackages;
      statsdPort = lib.mkIf cfg.enableMetrics service-ports.statsd;
    };
    systemd.timers."weekly-orchestratord-restart" =
      lib.mkIf cfg.enableOrchestrator {
        description = "Restart orchestratord weekly";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun 03:00";
          Persistent = true;
        };
      };
    systemd.services."weekly-orchestratord-restart" =
      lib.mkIf cfg.enableOrchestrator {
        description = "Restart orchestratord weekly";
        serviceConfig = {
          Type = "oneshot";
          ExecStart =
            "${pkgs.systemd}/bin/systemctl restart orchestratord.service";
        };
      };

    # The global useDHCP flag is deprecated, therefore explicitly set to false here.
    # Per-interface useDHCP will be mandatory in the future, so this generated config
    # replicates the default behaviour.
    networking.useDHCP = false;
    networking.networkmanager.enable = true;

    networking.firewall.allowedTCPPorts = [ 4444 ]
      ++ (if cfg.runWebServer then [ cfg.webServerInsecurePort ] else [ ]);

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us";
    };
    fonts.packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
    ];

    security.sudo.extraConfig = ''
      ${if cfg.isATS then "Defaults    timestamp_timeout=0" else ""}
    '';

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      settings = { X11Forwarding = true; };
    };
    programs.ssh.startAgent = true;

    programs.vim.enable = true;
    programs.vim.defaultEditor = true;

    services.journald = {
      rateLimitBurst = 0;
      rateLimitInterval = "0s";
    };

    # Metrics
    services.metricsNode.enable = cfg.enableMetrics;
    services.metricsNode.openFirewall = cfg.enableMetrics;

    # Notes Wiki
    services.notes-wiki.enable = cfg.serveNotesWiki;

    # Daily Tactical
    services.tacticald = lib.mkIf cfg.isATS {
      enable = true;
      user = "andrew";
      group = "dev";
      tacticalPkg = anixpkgs.daily_tactical_server;
      statsdPort = lib.mkIf cfg.enableMetrics service-ports.statsd;
    };

    # Media
    services.plexNode.enable = cfg.isATS;

    # Mail
    services.mailNode.enable = cfg.isATS;

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
        atsudo
      ] ++ (if cfg.machineType == "pi4" then [ libraspberrypi ] else [ ])
      ++ (if cfg.enableOrchestrator then
        [
          (let
            servicelist = builtins.concatStringsSep "/"
              (map (x: "${x.name}.service") cfg.timedOrchJobs);
            triggerscript = ./otrigger.py;
          in pkgs.writeShellScriptBin "otrigger" ''
            servicelist="${builtins.toString servicelist}"
            tmpdir=$(mktemp -d)
            ${python3}/bin/python ${triggerscript} "$servicelist" 2> $tmpdir/selection
            serviceselection=$(cat $tmpdir/selection)
            rm -r $tmpdir
            if [[ ! -z "$serviceselection" ]]; then
              echo "sudo systemctl restart ''${serviceselection}"
              ${atsudo}/bin/atsudo systemctl restart ''${serviceselection}
            fi
          '')
        ]
      else
        [ ]) ++ (if cfg.isATS then
          [
            (pkgs.writeShellScriptBin "atsrefresh" ''
              ${atsudo}/bin/atsudo systemctl stop orchestratord
              authm refresh --headless --force && rcrsync override secrets
              ${atsudo}/bin/atsudo systemctl start orchestratord
            '')
          ]
        else
          [ ]);

    programs.bash.interactiveShellInit = ''
      ${if cfg.developer then ''eval "$(direnv hook bash)"'' else ""}
       mkcd() {
          if [[ "$1" == "-h" || "$1" == "--help" ]]; then
              echo "usage: mkcd [-t|DIRNAME]"
          elif [[ "$1" == "-t" ]]; then
              cd "$(mktemp -d)" || return
          else
              mkdir -p "$1" && cd "$1" || return
          fi
      }
    '';

    environment.shellAliases = {
      jfu = "journalctl -fu";
      nohistory = "set +o history";
    };

    systemd.tmpfiles.rules =
      [ "d /data 0777 root root" "d /.c 0750 andrew dev -" "x /.c - - -" ];

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
        userOrchestrator = false;
        enableMetrics = cfg.enableMetrics;
      };
    };
  };
}
