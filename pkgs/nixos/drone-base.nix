{
  config,
  pkgs,
  lib,
  ...
}:
with import ./dependencies.nix;
let
  cfg = config.drone.base;
in
{
  options.drone.base = {
    homeRoot = lib.mkOption {
      type = lib.types.str;
      description = "Home root directory for primary user (default: /data)";
      default = "/data";
    };
    homeUser = lib.mkOption {
      type = lib.types.str;
      description = "Primary user (default: drone)";
      default = "drone";
    };
    nixosState = lib.mkOption {
      type = lib.types.str;
      description = "Initiating state of the NixOS install (example: '22.05')";
    };
    machine = lib.mkOption {
      type = lib.types.enum [ "sitl" ]; # TODO e.g., jetson, pi4
      description = "Machine that the closure is targeting.";
    };
    bootMntPt = lib.mkOption {
      type = lib.types.str;
      description = "(x86_linux) Boot partition mount point (default: /boot/efi)";
      default = "/boot";
    };
    runAPSITL = lib.mkOption {
      type = lib.types.bool;
      description = "Run Ardupilot onboard the computer in SITL mode (default: false). Configured via the services.ardupilot-sim option set.";
      default = false;
    };
    fcSerialDevice = lib.mkOption {
      type = lib.types.str;
      description = "Serial connection (<device>[:<baudrate>]) to an external flight controller, routed by mavlink-router when runAPSITL is false";
      default = "/dev/ttyACM0:115200";
    };
  };

  imports = [
    ../python-packages/orchestrator/module.nix
    ../cxx-packages/arducopter/sitl-module.nix
    ../cxx-packages/arducopter/router-module.nix
    ../cxx-packages/microxrce-dds-agent/module.nix
  ];

  config = {
    system.stateVersion = cfg.nixosState;

    boot = {
      kernelPackages =
        let
          machineKernelPkgs = {
            sitl = pkgs.linuxPackages_latest;
          };
        in
        machineKernelPkgs.${cfg.machine};
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
      loader =
        let
          machineLoaders = {
            sitl = {
              systemd-boot.enable = true;
              efi = {
                canTouchEfiVariables = true;
                efiSysMountPoint = cfg.bootMntPt;
              };
            };
          };
        in
        machineLoaders.${cfg.machine};
    };

    nix = {
      nixPath = [
        "nixos-config=/etc/nixos/configuration.nix"
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "anixpkgs=${cfg.homeRoot}/${cfg.homeUser}/sources/anixpkgs"
      ];
      settings = {
        auto-optimise-store = true;
        max-jobs = 4;
        cores = 4;
        substituters = [
          "https://cache.nixos.org/"
          "https://github-public.cachix.org"
          "https://ros.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "github-public.cachix.org-1:xofQDaQZRkCqt+4FMyXS5D6RNenGcWwnpAXRXJ2Y5kc="
          "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
        ];
      };
      extraOptions = ''
        narinfo-cache-positive-ttl = 0
        narinfo-cache-negative-ttl = 0
        experimental-features = nix-command flakes
      '';
    };

    nixpkgs.overlays = lib.mkForce [ ];

    time.timeZone = "America/Los_Angeles";

    networking.useDHCP = false;
    networking.networkmanager.enable = true;

    i18n.defaultLocale = "en_US.UTF-8";
    console = {
      font = "Lat2-Terminus16";
      keyMap = "us";
    };

    services.openssh = {
      enable = true;
      settings = {
        X11Forwarding = false;
      };
    };
    programs.ssh.startAgent = true;

    programs.vim.enable = true;
    programs.vim.defaultEditor = true;

    services.journald = {
      rateLimitBurst = 0;
      rateLimitInterval = "0s";
    };

    environment.systemPackages =
      let
        anix = pkgname: anixpkgs.${pkgname}.out;
      in
      with pkgs;
      (
        [
          ack
          procs
          tldr
          fzf
          fdupes
          zoxide
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
          # python with the S1 trajectory harness replaces the bare python3
          # (avoids a bin/python3 collision between two interpreters).
          (anixpkgs.python313.withPackages (ps: [ ps.indi-harness ]))
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
          tmux
          # TODO: anix upgrade workflows don't currently work without home-manager
          # (anixpkgs.anix-version.override { standalone = false; }).out
          # (anixpkgs.anix-upgrade.override {
          #   standalone = false;
          # }).out
        ]
        ++ (map (x: anix x) [
          "color-prints"
          "fix-perms"
          "secure-delete"
          "sunnyside"
          "make-title"
          "pb"
          "dirgroups"
          "dirgather"
          "fixfname"
          "nix-deps"
          "nix-diffs"
          # TODO: docs interfere
          # "orchestrator"
        ])
        ++ [
          # Core ROS2 infrastructure: rclcpp/rclpy, an rmw implementation, and
          # the ros2 CLI suite (ros2 topic/service/node/param/run/launch/...)
          (ros-pkgs.rosPackages.jazzy.buildEnv {
            paths = with ros-pkgs.rosPackages.jazzy; [
              ros-core
              demo-nodes-cpp
              demo-nodes-py
            ];
          })
        ]
      );

    services.ardupilot-sim = {
      enable = cfg.runAPSITL;
      package = anixpkgs.arducopter.sitl;
      rootDir = "${cfg.homeRoot}/${cfg.homeUser}/ardusitl";
      user = cfg.homeUser;
      group = "dev";
      # Native ROS2 interface: the AP_DDS client connects to the local Micro
      # XRCE-DDS agent over UDP. These match the Ardupilot defaults, but are
      # pinned here so upstream default changes can't silently break the
      # ROS2 bridge.
      # Upstream SITL copter defaults (frame class/type, INS calibration, RC
      # ranges): without them a fresh eeprom fails prearm ("Motors: Check
      # frame class and type", "3D Accel calibration needed") and the vehicle
      # can never arm — sim_vehicle.py always launches SITL with this file.
      baseDefaultsFile = "${anixpkgs.arducopter.sitl.src}/Tools/autotest/default_params/copter.parm";
      parameters = [
        "DDS_ENABLE 1"
        "DDS_DOMAIN_ID 0"
        "DDS_UDP_PORT ${toString service-ports.xrce-dds-agent}"
      ];
    };

    # Bridges the Ardupilot AP_DDS client into the ROS2 graph. Serial
    # transport for hardware flight controllers is TODO alongside the first
    # hardware machine target.
    services.microxrce-agent = {
      enable = true;
      package = anixpkgs.microxrce-dds-agent;
      transportArgs = "udp4 --port ${toString service-ports.xrce-dds-agent}";
      user = cfg.homeUser;
      group = "dev";
    };

    # The AP_DDS client gives up after DDS_MAX_RETRY failed pings, so make
    # sure the agent is up before the SITL starts.
    systemd.services.ardusitl = lib.mkIf cfg.runAPSITL {
      after = [ "microxrce-agent.service" ];
      wants = [ "microxrce-agent.service" ];
    };

    # MAVLink routing runs unconditionally: bound to the local SITL instance
    # when runAPSITL is set, otherwise to the external flight controller serial
    # connection.
    services.ardurouter = {
      enable = true;
      package = anixpkgs.ardurouter;
      rootDir = "${cfg.homeRoot}/${cfg.homeUser}/ardurouter";
      user = cfg.homeUser;
      group = "dev";
      interfaceArgs =
        if cfg.runAPSITL then
          "--tcp-endpoint 127.0.0.1:${toString service-ports.mavlink.ap-sitl-tcp} --tcp-port ${toString service-ports.mavlink.router-tcp}"
        else
          cfg.fcSerialDevice;
    };

    systemd.services.ardurouter = lib.mkIf cfg.runAPSITL {
      after = [ "ardusitl.service" ];
      wants = [ "ardusitl.service" ];
    };

    services.orchestratord = {
      enable = false; # TODO needed?
      user = cfg.homeUser;
      orchestratorPkg = anixpkgs.orchestrator;
      pathPkgs = with pkgs; [
        bash
        coreutils
      ];
    };

    environment.shellAliases = {
      jfu = "journalctl -fu";
      nohistory = "set +o history";
    };

    systemd.tmpfiles.rules = [ "d ${cfg.homeRoot} 0777 root root" ];

    users.groups.dev = {
      gid = 1000;
    };

    users.users.${cfg.homeUser} = {
      isNormalUser = true;
      uid = 1000;
      home = "${cfg.homeRoot}/${cfg.homeUser}";
      createHome = true;
      description = "Primary User";
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
      hashedPassword = "$6$0fv.6VfJi8qfOLtZ$nJ9OeiLzDenXaogPJl1bIe6ipx4KTnsyPExB.9sZk/dEXfFv34PtRRxZf28RKwrpcg5bgmee6QiQFGQQhv4rS/";
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDARsquoLlZN+DIsqoBh1tQ4h5E+V1UD7SpBZCpzcWMHY+N8SJ6CnYKUiQU8FSCWSOhdZ1r52za+iMl0g983S71cH70attk5KvQYHYGfqpSckwIQ326wE6e+fPQAytgqv6CS+xjNzcpRwVRzBmlB1IyqNCl79OnWsg0TXxL/GBt3UUI9p6XjAeZhxpqb2NPZYHV+TZPPvI3/1X0LadBZZWFPbtoI+XbHABtW06YUDpR+BQSpFGtq+2eIjRgoo4WEHPewV73zzLVIYZ3xaa0Whmm4qTPpNtw+U1tHZkxUAjU92Y7Mq7oehd5z6YGRQ+UxSAuSYkR7xTt63KFb/vTjJg0W0LphwPYnfzG1M+jhK/6rGAdL0AYaUiMDTwl6gSkROKAzab63wf9gbeo+6Smgv3LQYCXvAFccEKtqlt1RLP/SUdTCdjVL728c0+WohrOD3tyRR8XU94CdOyLrhRG0k4Bcb0W0GYaLxsUSkc/wSyg6An9ITldBfH0FOON2sft52M= andrew@andrew-Precision-5550"
      ];
    };
    users.mutableUsers = true;

    programs.wireshark.enable = true;
  };
}
