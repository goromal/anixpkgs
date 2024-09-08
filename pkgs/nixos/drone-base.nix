{ config, pkgs, lib, ... }:
with import ./dependencies.nix { inherit config; };
let cfg = config.drone.base;
in {
  options.drone.base = {
    homeDir = lib.mkOption {
      type = lib.types.str;
      description = "Home directory for primary user (default: /data/andrew)";
      default = "/data/andrew";
    };
    nixosState = lib.mkOption {
      type = lib.types.str;
      description = "Initiating state of the NixOS install (example: '22.05')";
    };
    machine = lib.mkOption {
      type = lib.types.enum [ "sitl" ]; # TODO e.g., pi4
      description = "Machine that the closure is targeting.";
    };
    bootMntPt = lib.mkOption {
      type = lib.types.str;
      description =
        "(x86_linux) Boot partition mount point (default: /boot/efi)";
      default = "/boot/efi";
    };
  };

  imports = [ ../../python-packages/orchestrator/module.nix ];

  config = {
    system.stateVersion = cfg.nixosState;

    boot = {
      kernelPackages =
        let machineKernelPkgs = { sitl = pkgs.linuxPackages_latest; };
        in kernelPackages.${cfg.machine};
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
      loader = let
        machineLoaders = {
          sitl = {
            systemd-boot.enable = true;
            efi = {
              canTouchEfiVariables = true;
              efiSysMountPoint = cfg.bootMntPt;
            };
          };
        };
      in machineLoaders.${cfg.machine};
    };

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
      settings = { X11Forwarding = true; };
    };
    programs.ssh.startAgent = true;

    programs.vim.defaultEditor = true;

    services.journald = {
      rateLimitBurst = 0;
      rateLimitInterval = "0s";
    };

    environment.systemPackages = with pkgs; [
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
      tmux
      (anixpkgs.anix-version.override { standalone = false; })
      (anixpkgs.anix-upgrade.override {
        standalone = false;
        browser-aliases = null;
      })
      anixpkgs.color-prints
      anixpkgs.fix-perms
      anixpkgs.secure-delete
      anixpkgs.sunnyside
      anixpkgs.make-title
      anixpkgs.pb
      anixpkgs.dirgroups
      anixpkgs.dirgather
      anixpkgs.fixfname
      anixpkgs.nix-deps
      anixpkgs.nix-diffs
      anixpkgs.orchestrator
    ];
  };
}
