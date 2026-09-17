args@{
  config,
  pkgs,
  lib,
  ...
}:
with import ./dependencies.nix;
let
  cfg = config.machines.base;
  features = config.machines.features;
  remoteBuildersCatalog = import ./remote-builders.nix;
  home-manager-nixos-module =
    if args ? hmModule then
      args.hmModule
    else
      (import "${builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz"}/nixos");
  inherit (import ./runtime.nix { inherit config pkgs lib; }) atsudo machine-rcrsync machine-authm;
  anix-init = pkgs.writeShellScriptBin "anix-init" ''
    make-title -c yellow "Setting up rcrsync"

    DO_RCLONE=y
    if [[ -f $HOME/.config/rclone/rclone.conf ]]; then
      read -rp "rclone config already found, proceed anyway? (y|n): " DO_RCLONE
    fi
    if [[ "$DO_RCLONE" == "y" ]]; then
      read -rp "Enter the char key to unlock the rclone config: " CFGKEY
      rm -rf $HOME/.config/rclone
      mkdir -p $HOME/.config/rclone && cd $HOME/.config/rclone
      cp ${anixpkgs.pkgData.records.rcloneConf.data} ${anixpkgs.pkgData.records.rcloneConf.name}
      sunnyside -s 0 -k $CFGKEY -t ${anixpkgs.pkgData.records.rcloneConf.name}
      rm ${anixpkgs.pkgData.records.rcloneConf.name}
    else
      echo_yellow "Skipping rclone config step"
    fi

    cd $HOME
    ${lib.concatMapStrings (dir: "rcrsync -v init ${dir.name}\n") cfg.cloudDirs}
    make-title -c yellow "Setting up SSH and Nix"

    DO_SSH=y
    if [[ -d $HOME/.ssh ]]; then
      read -rp ".ssh directory already present, proceed anyway? (y|n): " DO_SSH
    fi
    if [[ "$DO_SSH" == "y" ]]; then
      rm -rf $HOME/.ssh
      cp -r $HOME/data/.ssh $HOME/.ssh
      cd $HOME/.ssh
      fix-perms .
      cd ..
    else
      echo_yellow "Skipping SSH config setup"
    fi

    echo
    echo_green "DONE. Note the hardware-config.nix file below:"
    echo
    nixos-generate-config --show-hardware-config
    echo
    echo_green "Next steps to finish configuring this machine:"
    echo_yellow "  - Use devshell to create a workspace with anixpkgs"
    echo_yellow "  - Copy the hardware config above into anixpkgs/pkgs/nixos/hardware/"
    echo_yellow "  - Define the machine in pkgs/nixos/configurations/ and set networking.hostName"
    echo_yellow "  - Add it to flake.nix with scripts/add-machine-to-flake.py (personal/Jetson)"
    echo_yellow "  - Ensure the flake attribute matches the runtime hostname: $(hostname)"
    echo_yellow "  - Run anix-upgrade"
    echo_yellow "  - Create new secrets and configs entries"
    echo
    echo_green "Have fun!"
  '';
in
{
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
      type = lib.types.enum [
        "x86_linux"
        "pi4"
        "jetson"
      ];
      description = "Machine type that the closure is targeting.";
    };
    bootMntPt = lib.mkOption {
      type = lib.types.str;
      description = "(x86_linux) Boot partition mount point (default: /boot/efi)";
      default = "/boot";
    };
    runWebServer = lib.mkOption {
      type = lib.types.bool;
      internal = true;
      description = "Whether to spawn a reverse proxy webserver.";
      default = false;
    };
    webServices = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name of the service";
            };
            tag = lib.mkOption {
              type = lib.types.str;
              description = "Landing-page group for the service";
            };
            path = lib.mkOption {
              type = lib.types.str;
              description = "URL path or full URL to the service";
            };
            description = lib.mkOption {
              type = lib.types.str;
              description = "Brief description of the service";
            };
            port = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = "Dedicated public port, or null for a path on the shared webserver.";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              description = "Font Awesome 6 solid icon class name (e.g. 'arrows-rotate')";
              default = "";
            };
            faviconSvg = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              description = "Path to SVG file served and linked at {path}favicon.svg; null disables";
              default = null;
            };
          };
        }
      );
      description = "List of web services to display on landing page";
      default = [ ];
    };
    wifiInterfaceName = lib.mkOption {
      type = lib.types.str;
      description = "Network interface name for the WiFi.";
      default = "wlo1";
    };
    webServerInsecurePort = lib.mkOption {
      type = lib.types.port;
      description = "Public insecure port";
      default = 80;
    };
    webServerSecurePort = lib.mkOption {
      type = lib.types.port;
      description = "Public secure port";
      default = 443;
    };
    cloudDirs = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            cloudname = lib.mkOption { type = lib.types.str; };
            dirname = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      description = "List of {name,cloudname,dirname} attributes (dirname is relative to home) defining the syncable directories by rcrsync";
    };
    remoteBuilders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Keys into remote-builders.nix catalog of LAN build machines to use for distributed builds.";
    };
    acceptRemoteBuilds = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether this machine accepts build jobs from other LAN hosts via SSH.";
    };
  };

  imports = [
    ./installation-base.nix
    ./features/options.nix
    ./features/services.nix
    ./features/notebooks.nix
    ./features/orchestrator.nix
    ./features/game-streaming.nix
    home-manager-nixos-module
    ../modules/agent-common/module.nix
    ../modules/claude-agent/module.nix
    ../modules/codex-agent/module.nix
    ../modules/webserverNode/module.nix
    ../modules/cudaNode/module.nix
    ../modules/localLlm/module.nix
    ../modules/comfyui/module.nix
    ../modules/externalDrives/module.nix
    ../modules/homeVpnNode/module.nix
    ../modules/notes-wiki/module.nix
    ../modules/metricsNode/module.nix
    ../modules/plexNode/module.nix
    ../modules/mailNode/module.nix
    ../modules/vikunja/module.nix
    ../modules/vikunja-mcp/module.nix
    ../modules/folio/module.nix
    ../modules/folio-mcp/module.nix
    ../modules/gmail-mcp/module.nix
    ../modules/navidrome/module.nix
    ../modules/notion-mcp/module.nix
    ../modules/wiki-mcp/module.nix
    ../modules/jupyter-mcp/module.nix
    ../modules/google-sheets-mcp/module.nix
    ../python-packages/orchestrator/module.nix
    ../python-packages/daily_tactical_server/module.nix
    ../python-packages/flasks/authui/module.nix
    ../python-packages/flasks/budget_ui/module.nix
    ../python-packages/flasks/orchestrator_ui/module.nix
    ../python-packages/flasks/rankserver/module.nix
    ../python-packages/flasks/stampserver/module.nix
    ../python-packages/flasks/la-quiz-web/module.nix
    ../python-packages/flasks/anix-upgrade-ui/module.nix
    ../python-packages/flasks/agent_ui/module.nix
    ../python-packages/flasks/sunset/module.nix
    ../python-packages/flasks/tester/module.nix
    ../python-packages/flasks/disciple/module.nix
    ../modules/launchpad/module.nix
    ../python-packages/flasks/tasks_ui/module.nix
    ../python-packages/flasks/videodl/module.nix
    ../python-packages/flasks/brom/module.nix
    ../python-packages/flasks/intake_ui/module.nix
    ../python-packages/flasks/mail/module.nix
  ];

  config = lib.mkMerge [
    {
      # Fail evaluation if two services claim the same port.
      #
      # This is specifically a merge hazard: two branches can each add a
      # DIFFERENT key with the SAME value to service-ports.nix, which git
      # merges without a textual conflict because the added lines don't
      # overlap. `brom` and `agent_ui` both took 6767 exactly that way, and
      # the collision only surfaced after deployment as a unit crash-looping
      # on "Address already in use" — by which point the other service had
      # already won the bind. Checking keys is not enough; check values.
      assertions =
        let
          flattenPorts =
            prefix: attrs:
            lib.concatLists (
              lib.mapAttrsToList (
                n: v:
                let
                  path = if prefix == "" then n else "${prefix}.${n}";
                in
                if builtins.isInt v then
                  [
                    {
                      name = path;
                      port = v;
                    }
                  ]
                else if builtins.isAttrs v then
                  flattenPorts path v
                else
                  [ ]
              ) attrs
            );
          entries = flattenPorts "" service-ports;
          duplicates = lib.filterAttrs (_: es: builtins.length es > 1) (
            lib.groupBy (e: builtins.toString e.port) entries
          );
          rendered = lib.concatStringsSep "; " (
            lib.mapAttrsToList (
              p: es: "${p} claimed by ${lib.concatStringsSep " and " (map (e: e.name) es)}"
            ) duplicates
          );
        in
        [
          {
            assertion = duplicates == { };
            message = "service-ports.nix assigns the same port to more than one service: ${rendered}. Two services cannot bind the same port — pick a free value.";
          }
        ];

      system.stateVersion = cfg.nixosState;

      users.groups.jtop = lib.mkIf (cfg.machineType == "jetson") { };
      users.users.andrew.extraGroups = lib.mkIf (cfg.machineType == "jetson") [ "jtop" ];

      systemd.services.nvpmodel = lib.mkIf (cfg.machineType == "jetson") (
        let
          mode3Conf = pkgs.runCommand "nvpmodel-p3767-mode3.conf" { } ''
            sed 's/PM_CONFIG DEFAULT=2/PM_CONFIG DEFAULT=3/' \
              ${pkgs.nvidia-jetpack.l4t-nvpmodel}/etc/nvpmodel/nvpmodel_p3767_0000.conf > $out
          '';
        in
        {
          serviceConfig.ExecStart = lib.mkForce "${pkgs.nvidia-jetpack.l4t-nvpmodel}/bin/nvpmodel -f ${mode3Conf}";
        }
      );

      systemd.services.jetson-nvpmodel-maxn = lib.mkIf (cfg.machineType == "jetson") (
        let
          script = pkgs.writeShellScript "jetson-nvpmodel-maxn" ''
            current=$(${pkgs.nvidia-jetpack.l4t-nvpmodel}/bin/nvpmodel -q | tail -1)
            if [ "$current" = "3" ]; then exit 0; fi
            exec ${pkgs.nvidia-jetpack.l4t-nvpmodel}/bin/nvpmodel -m 3 --force
          '';
        in
        {
          description = "Force Jetson to 25W nvpmodel (all cores), rebooting once if needed";
          after = [ "nvpmodel.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${script}";
            RemainAfterExit = true;
          };
        }
      );

      systemd.services.jtop = lib.mkIf (cfg.machineType == "jetson") {
        description = "jtop service";
        after = [ "systemd-modules-load.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.util-linux ];
        environment.JTOP_SERVICE = "True";
        serviceConfig = {
          ExecStart = "${anixpkgs.jetson-stats}/bin/jtop --force";
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStartSec = "30s";
          TimeoutStopSec = "30s";
          StateDirectory = "jtop";
        };
      };

      boot = {
        kernelPackages = lib.mkIf (cfg.machineType != "jetson") (
          if cfg.machineType == "pi4" then pkgs.linuxPackages_rpi4 else pkgs.linuxPackages_latest
        );
        kernel.sysctl = lib.mkIf (cfg.machineType != "jetson") {
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
          # Use the systemd-boot EFI boot loader for x86_linux and Jetson
          # Grub is used on Raspberry Pi
          systemd-boot.enable = (cfg.machineType == "x86_linux" || cfg.machineType == "jetson");
          grub.enable = lib.mkForce (cfg.machineType == "pi4");
          grub.efiSupport = lib.mkIf (cfg.machineType == "pi4") true;
          grub.device = lib.mkIf (cfg.machineType == "pi4") "nodev";
          efi = {
            canTouchEfiVariables = (cfg.machineType == "x86_linux" || cfg.machineType == "jetson");
            efiSysMountPoint = lib.mkIf (cfg.machineType == "x86_linux") cfg.bootMntPt;
          };
          generic-extlinux-compatible.enable = lib.mkForce false;
        };
        supportedFilesystems = lib.mkIf (cfg.machineType == "x86_linux") [ "ntfs" ];
        binfmt.emulatedSystems = lib.mkIf (cfg.machineType == "x86_linux") [ "aarch64-linux" ];

        postBootCommands = lib.mkIf (cfg.machineType == "x86_linux" && features.desktop.enable) (
          let
            gdm_user_conf = ''
              [User]
              Session=
              XSession=
              Icon=${cfg.homeDir}/.face
              SystemAccount=false
            '';
          in
          ''
            echo '${gdm_user_conf}' > /var/lib/AccountsService/users/andrew
          ''
        );
      };

      # https://github.com/NixOS/nixpkgs/issues/154163
      nixpkgs.overlays = lib.mkIf (cfg.machineType == "pi4") [
        (final: super: {
          # modprobe: FATAL: Module sun4i-drm not found
          makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
        })
      ];

      nix.nixPath = [
        "nixos-config=/etc/nixos/configuration.nix"
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
        "anixpkgs=${cfg.homeDir}/sources/anixpkgs"
      ];

      nix.distributedBuilds = cfg.remoteBuilders != [ ];
      nix.buildMachines = map (name: remoteBuildersCatalog.${name}) cfg.remoteBuilders;
      nix.settings.trusted-users = lib.mkIf cfg.acceptRemoteBuilds [ "andrew" ];

      services.xserver.enable = lib.mkIf (cfg.machineType == "x86_linux" && features.desktop.enable) true;
      services.displayManager.gdm.enable = lib.mkIf (
        cfg.machineType == "x86_linux" && features.desktop.enable
      ) true;
      services.desktopManager.gnome.enable = lib.mkIf (
        cfg.machineType == "x86_linux" && features.desktop.enable
      ) true;

      services.printing.enable = (cfg.machineType == "x86_linux" && features.desktop.enable);

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

      environment.gnome = lib.mkIf (cfg.machineType == "x86_linux" && features.desktop.enable) {
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
      hardware.bluetooth = lib.mkIf (features.headsetAudio.enable) {
        enable = true;
        settings = {
          General = {
            ControllerMode = "bredr";
          };
        };
      };
      services.blueman.enable = lib.mkIf (features.headsetAudio.enable) true;
      services.pulseaudio.enable = lib.mkIf (features.headsetAudio.enable) false;
      security.rtkit.enable = lib.mkIf (features.headsetAudio.enable) true;
      services.pipewire = lib.mkIf (features.headsetAudio.enable) {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        jack.enable = true;
      };

      services.udev.packages = lib.mkIf (
        cfg.machineType == "x86_linux" && features.desktop.enable && features.recreation.enable
      ) [ pkgs.dolphin-emu ];

      networking.firewall.allowedTCPPorts = [
        4444
      ]
      ++ (
        if cfg.runWebServer then
          [
            cfg.webServerInsecurePort
            cfg.webServerSecurePort
          ]
        else
          [ ]
      );

      fonts.packages = with pkgs; [
        dejavu_fonts
        liberation_ttf
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];

      programs.ssh.startAgent = (features.desktop.enable == false);

      programs.vim.enable = true;
      programs.vim.defaultEditor = true;

      services.journald = {
        rateLimitBurst = 0;
        rateLimitInterval = "0s";
      };

      # Global packages
      environment.systemPackages =
        with pkgs;
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
          git
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
          smartmontools
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
          picocom
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
          ffmpeg-headless
          ffmpegthumbnailer
        ]
        ++ (if cfg.machineType == "pi4" then [ libraspberrypi ] else [ ])
        ++ (
          if features.auth.enable then
            [
              (pkgs.writeShellScriptBin "atsrefresh" ''
                ${lib.optionalString features.orchestrator.enable "${atsudo}/bin/atsudo systemctl stop orchestratord"}
                authm refresh --headless --force && rcrsync override secrets
                ${lib.optionalString features.orchestrator.enable "${atsudo}/bin/atsudo systemctl start orchestratord"}
              '')
            ]
          else
            [ ]
        )
        ++ (if cfg.runWebServer then [ anixpkgs.generate-local-ssl-certs ] else [ ])
        ++ [ anix-init ];

      programs.bash.interactiveShellInit = ''
        ${if features.development.enable then ''eval "$(direnv hook bash)"'' else ""}
        tmux() {
          command tmux "$@"
          local _tmux_exit=$?
          tput rmcup 2>/dev/null
          tput cnorm 2>/dev/null
          stty sane 2>/dev/null
          return $_tmux_exit
        }
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
        ta = "tmux attach";
      };

      programs.captive-browser = {
        enable = features.desktop.enable;
        interface = cfg.wifiInterfaceName;
      };

      systemd.tmpfiles.rules = [
        "d /.c 0750 andrew dev -"
        "x /.c - - -"
      ];

      # Allow profiles to override the home directory (installation-base.nix sets
      # the default of /data/andrew for all other user attributes).
      users.users.andrew.home = lib.mkForce cfg.homeDir;

      programs.wireshark.enable = true;

      home-manager.users.andrew =
        lib.recursiveUpdate
          {
            programs.home-manager.enable = true;
            programs.command-not-found.enable = true;

            imports = [
              ./components/opts.nix
              ./components/base-pkgs.nix
              ./components/upgrade-hooks.nix
            ]
            ++ (if features.development.enable then [ ./components/base-dev-pkgs.nix ] else [ ])
            ++ (lib.optionals (lib.elem "claude" features.agents.frameworks) [ ./components/claude-agent.nix ])
            ++ (lib.optionals (lib.elem "codex" features.agents.frameworks) [ ./components/codex-agent.nix ])
            ++ (if cfg.machineType == "pi4" then [ ./components/pi-pkgs.nix ] else [ ])
            ++ (
              if cfg.machineType == "x86_linux" then
                (
                  [ ./components/x86-pkgs.nix ]
                  ++ (if features.recreation.enable then [ ./components/x86-rec-pkgs.nix ] else [ ])
                  ++ (
                    if features.desktop.enable then
                      (
                        [ ./components/x86-graphical-pkgs.nix ]
                        ++ (if features.development.enable then [ ./components/x86-graphical-dev-pkgs.nix ] else [ ])
                        ++ (if features.recreation.enable then [ ./components/x86-graphical-rec-pkgs.nix ] else [ ])
                        ++ (
                          if (features.development.enable && features.recreation.enable) then
                            [ ./components/x86-graphical-dev-rec-pkgs.nix ]
                          else
                            [ ]
                        )
                      )
                    else
                      [ ]
                  )
                )
              else
                [ ]
            );

            mods.opts = {
              homeState = cfg.nixosState;
              standalone = false;
              homeDir = cfg.homeDir;
              browserExec =
                if features.desktop.enable && cfg.machineType == "x86_linux" then
                  "${unstable.google-chrome}/bin/google-chrome-stable"
                else
                  null;
              cloudDirs = cfg.cloudDirs;
              userOrchestrator = false;
              enableMetrics = features.metrics.enable;
            };
          }
          (
            lib.foldl lib.recursiveUpdate { } [
              (lib.optionalAttrs (lib.elem "claude" features.agents.frameworks) {
                mods.claude = {
                  marketplaces = config.machines.claude.marketplaces;
                  plugins = config.machines.claude.plugins;
                  permissionsAllow = config.machines.claude.permissionsAllow;
                  hooks = config.machines.claude.hooks;
                  skills = config.machines.claude.skills;
                  extraSettings = config.machines.claude.extraSettings;
                  mcpServers = config.machines.claude.mcpServers;
                  graphical = features.desktop.enable;
                };
              })
              (lib.optionalAttrs (lib.elem "codex" features.agents.frameworks) {
                mods.codex = {
                  model = config.machines.codex.model;
                  modelProvider = config.machines.codex.modelProvider;
                  approvalPolicy = config.machines.codex.approvalPolicy;
                  sandboxMode = config.machines.codex.sandboxMode;
                  extraSettings = config.machines.codex.extraSettings;
                  skills = config.machines.codex.skills;
                  mcpServers = config.machines.codex.mcpServers;
                  graphical = features.desktop.enable;
                };
              })
            ]
          );
    }
  ];
}
