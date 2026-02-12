{
  description = "A collection of personal (or otherwise personally useful) software packaged in Nix.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=refs/tags/25.11";

    jetpack-nixos.url = "github:anduril/jetpack-nixos";

    phps.url = "github:fossar/nix-phps";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    flake-utils.url = "github:numtide/flake-utils";

    anixdata.url = "github:goromal/anixdata";
    anixdata.flake = false;

    aapis.url = "github:goromal/aapis";
    aapis.flake = false;

    ardupilot.url = "git+ssh://git@github.com/goromal/ardupilot?ref=master&submodules=1";
    ardupilot.flake = false;

    book-notes-sync.url = "github:goromal/book-notes-sync";
    book-notes-sync.flake = false;

    ceres-factors.url = "github:goromal/ceres-factors";
    ceres-factors.flake = false;

    crowcpp.url = "github:goromal/Crow";
    crowcpp.flake = false;

    daily_tactical_server.url = "github:goromal/daily_tactical_server";
    daily_tactical_server.flake = false;

    easy-google-auth.url = "github:goromal/easy-google-auth";
    easy-google-auth.flake = false;

    evil-hangman.url = "github:goromal/evil-hangman";
    evil-hangman.flake = false;

    find_rotational_conventions.url = "git+https://gist.github.com/fb15f44150ca4e0951acaee443f72d3e";
    find_rotational_conventions.flake = false;

    geometry.url = "github:goromal/geometry?ref=dev/25.11";
    geometry.flake = false;

    gmail-parser.url = "github:goromal/gmail_parser";
    gmail-parser.flake = false;

    gnc.url = "github:goromal/gnc";
    gnc.flake = false;

    # TODO gradebook would need dev/warn-suppress branch

    makepyshell.url = "git+https://gist.github.com/e64b6bdc8a176c38092e9bde4c434d31";
    makepyshell.flake = false;

    manif-geom-cpp.url = "github:goromal/manif-geom-cpp?ref=refs/tags/release/1.0";
    manif-geom-cpp.flake = false;

    manif-geom-rs.url = "github:goromal/manif-geom-rs";
    manif-geom-rs.flake = false;

    mavlink.url = "github:mavlink/c_library_v2?rev=f9cec4814082af27c2fd27259aed302f52ce9cf7";
    mavlink.flake = false;

    mavlink-router.url = "github:mavlink-router/mavlink-router";
    mavlink-router.flake = false;

    mavlog-utils.url = "github:goromal/mavlog-utils";
    mavlog-utils.flake = false;

    mesh-plotter.url = "github:goromal/mesh-plotter";
    mesh-plotter.flake = false;

    mfn.url = "github:goromal/mfn";
    mfn.flake = false;

    mscpp.url = "github:goromal/mscpp";
    mscpp.flake = false;

    orchestrator.url = "github:goromal/orchestrator";
    orchestrator.flake = false;

    orchestrator-cpp.url = "github:goromal/orchestrator-cpp";
    orchestrator-cpp.flake = false;

    photos-tools.url = "github:goromal/photos-tools";
    photos-tools.flake = false;

    pyceres.url = "github:Edwinem/ceres_python_bindings?rev=2106d043bce37adcfef450dd23d3005480948c37";
    pyceres.flake = false;

    pyceres_factors.url = "github:goromal/pyceres_factors?ref=dev/25.11";
    pyceres_factors.flake = false;

    pysignals.url = "github:goromal/pysignals?ref=dev/25.11";
    pysignals.flake = false;

    pysorting.url = "github:goromal/pysorting?ref=dev/25.11";
    pysorting.flake = false;

    python-dokuwiki.url = "github:fmenabe/python-dokuwiki?ref=refs/tags/1.3.3";
    python-dokuwiki.flake = false;

    quad-sim-cpp.url = "github:goromal/quad-sim-cpp";
    quad-sim-cpp.flake = false;

    rankserver-cpp.url = "github:goromal/rankserver-cpp";
    rankserver-cpp.flake = false;

    rcdo.url = "github:goromal/rcdo";
    rcdo.flake = false;

    scrape.url = "github:goromal/scrape";
    scrape.flake = false;

    secure-delete.url = "github:goromal/secure-delete";
    secure-delete.flake = false;

    signals-cpp.url = "github:goromal/signals-cpp?ref=refs/tags/release/1.0";
    signals-cpp.flake = false;

    simple-image-editor.url = "github:goromal/simple-image-editor";
    simple-image-editor.flake = false;

    sorting.url = "github:goromal/sorting";
    sorting.flake = false;

    spelling-corrector.url = "github:goromal/spelling-corrector";
    spelling-corrector.flake = false;

    sunnyside.url = "github:goromal/sunnyside";
    sunnyside.flake = false;

    symforce.url = "github:symforce-org/symforce?ref=refs/tags/v0.9.0";
    symforce.flake = false;

    task-tools.url = "github:goromal/task-tools";
    task-tools.flake = false;

    trafficsim.url = "git+https://gist.github.com/c37629235750b65b9d0ec0e17456ee96";
    trafficsim.flake = false;

    wiki-tools.url = "github:goromal/wiki-tools";
    wiki-tools.flake = false;

    xv-lidar-rs.url = "github:goromal/xv-lidar-rs";
    xv-lidar-rs.flake = false;
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      jetpack-nixos,
      ...
    }@inputs:
    let
      supported-systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      nixos-version = builtins.readFile ./NIXOS_VERSION;
      anixpkgsOverlay = import ./overlay.nix;
    in
    flake-utils.lib.eachSystem supported-systems (system: {
      legacyPackages = import nixpkgs {
        inherit system;
        overlays = [ anixpkgsOverlay ];
        config = {
          allowUnfree = true;
          flakeInputs = inputs;
        };
      };
    })
    // {
      nixosConfigurations = {
        # x86_64 personal installer ISO
        # Build: nix build .#nixosConfigurations.installer-personal.config.system.build.isoImage
        installer-personal = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit nixos-version; };
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
            ./pkgs/nixos/installation-base.nix
            (
              { lib, pkgs, ... }:
              {
                nixpkgs.overlays = [ anixpkgsOverlay ];
                nixpkgs.config.allowUnfree = true;
                networking.wireless.enable = lib.mkForce false;

                environment.systemPackages = [
                  (pkgs.writeShellScriptBin "anix-install" ''
                    set -euo pipefail

                    # --- CONFIGURATION ---
                    BOOT_LABEL="EFI"
                    ROOT_LABEL="NixOS"
                    BOOT_SIZE="512MiB"

                    # --- DETECT DRIVE ---
                    echo "Detecting drives..."
                    lsblk -dno NAME,SIZE,MODEL | grep -v loop
                    echo
                    read -rp "Enter target disk (e.g., sda, nvme0n1): " DRIVE

                    DISK="/dev/$DRIVE"
                    if [ ! -b "$DISK" ]; then
                      echo "Error: $DISK does not exist."
                      exit 1
                    fi

                    echo "WARNING: This will ERASE ALL DATA on $DISK"
                    read -rp "Type 'YES' to continue: " CONFIRM
                    if [ "$CONFIRM" != "YES" ]; then
                      echo "Aborted."
                      exit 1
                    fi

                    # --- WIPE EXISTING SIGNATURES ---
                    echo "Wiping filesystem signatures..."
                    wipefs --all "$DISK"

                    # --- CREATE PARTITIONS ---
                    echo "Creating GPT partition table..."
                    parted -s "$DISK" mklabel gpt

                    echo "Creating EFI partition..."
                    parted -s "$DISK" mkpart primary fat32 1MiB "$BOOT_SIZE"
                    parted -s "$DISK" set 1 esp on
                    parted -s "$DISK" name 1 "$BOOT_LABEL"

                    echo "Creating root partition..."
                    parted -s "$DISK" mkpart primary ext4 "$BOOT_SIZE" 100%
                    parted -s "$DISK" name 2 "$ROOT_LABEL"

                    # --- FORMAT PARTITIONS ---
                    EFI_PART="''${DISK}1"
                    ROOT_PART="''${DISK}2"

                    # Adjust naming for NVMe drives (nvme0n1p1 etc.)
                    if [[ "$DRIVE" == nvme* ]]; then
                      EFI_PART="''${DISK}p1"
                      ROOT_PART="''${DISK}p2"
                    fi

                    echo "Formatting EFI partition as FAT32..."
                    mkfs.fat -F 32 -n "$BOOT_LABEL" "$EFI_PART"

                    echo "Formatting root partition as ext4..."
                    mkfs.ext4 -L "$ROOT_LABEL" "$ROOT_PART"

                    # --- MOUNT PARTITIONS ---
                    echo "Mounting partitions..."
                    sleep 10
                    mkdir -p /mnt/nixos
                    mount /dev/disk/by-label/''${ROOT_LABEL} /mnt/nixos

                    mkdir -p /mnt/nixos/boot
                    mount /dev/disk/by-label/''${BOOT_LABEL} /mnt/nixos/boot
                    echo
                    echo "Done!"
                    echo "Partitions created and mounted as:"
                    lsblk "$DISK"
                    echo
                    echo "Mounted at /mnt/nixos and /mnt/nixos/boot"

                    # --- INSTALL NIXOS ---
                    echo
                    echo "Installing NixOS profile..."
                    nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixpkgs
                    nix-channel --add https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz home-manager
                    nix-channel --update
                    nixos-generate-config --root /mnt/nixos
                    sudo -u andrew bash <<'EOF'
                    cd /data/andrew
                    git clone https://github.com/goromal/anixpkgs.git
                    cp /mnt/nixos/etc/nixos/hardware-configuration.nix anixpkgs/pkgs/nixos/hardware/temp.nix
                    cp anixpkgs/pkgs/nixos/configurations/personal-inspiron.nix anixpkgs/pkgs/nixos/configurations/personal-temp.nix
                    sed -i 's/inspiron/temp/g' anixpkgs/pkgs/nixos/configurations/personal-temp.nix
                    sed -i 's/machines\.base\.nixosState *= *"[^"]*"/machines.base.nixosState = "${nixos-version}"/' anixpkgs/pkgs/nixos/configurations/personal-temp.nix
                    sed -i '/bootMntPt/d' anixpkgs/pkgs/nixos/configurations/personal-temp.nix
                    mkdir -p ~/.config/nixpkgs
                    echo "{ allowUnfree = true; }" > ~/.config/nixpkgs/config.nix
                    EOF
                    mkdir -p /root/.config/nixpkgs
                    cp /data/andrew/.config/nixpkgs/config.nix /root/.config/nixpkgs
                    rm /mnt/nixos/etc/nixos/*
                    ln -s /data/andrew/anixpkgs/pkgs/nixos/configurations/personal-temp.nix /mnt/nixos/etc/nixos/configuration.nix
                    nixos-install --root /mnt/nixos
                    echo "Done! Please shutdown and reboot, then proceed with the anix-init command while connected to the internet."
                  '')
                ];
              }
            )
          ];
        };

        # aarch64 JetPack installer ISO (cross-compiled from x86_64)
        # Build: nix build .#nixosConfigurations.installer-jetpack.config.system.build.isoImage
        installer-jetpack =
          let
            jetpackNixpkgs = jetpack-nixos.inputs.nixpkgs;
          in
          jetpackNixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            modules = [
              "${jetpackNixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              "${jetpackNixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
              jetpack-nixos.nixosModules.default
              ./pkgs/nixos/installation-base.nix
              (
                { lib, pkgs, ... }:
                {
                  nixpkgs.overlays = [ anixpkgsOverlay ];
                  nixpkgs.config.allowUnfree = true;
                  nixpkgs.hostPlatform = "aarch64-linux";
                  nixpkgs.buildPlatform = "x86_64-linux";
                  networking.wireless.enable = lib.mkForce false;
                  # The installer only needs to boot and run anix-install; disable CUDA
                  # to avoid capability/cross-compilation assertion failures in nixpkgs.
                  hardware.nvidia-jetpack.configureCuda = lib.mkForce false;
                  hardware.enableAllHardware = lib.mkForce false;

                  environment.systemPackages = [
                    (pkgs.writeShellScriptBin "anix-install" ''
                      set -euo pipefail

                      # --- CONFIGURATION ---
                      BOOT_LABEL="EFI"
                      ROOT_LABEL="NixOS"
                      BOOT_SIZE="512MiB"

                      # --- DETECT DRIVE ---
                      echo "Detecting drives..."
                      lsblk -dno NAME,SIZE,MODEL | grep -v loop
                      echo
                      read -rp "Enter target disk (e.g., sda, nvme0n1): " DRIVE

                      DISK="/dev/$DRIVE"
                      if [ ! -b "$DISK" ]; then
                        echo "Error: $DISK does not exist."
                        exit 1
                      fi

                      echo "WARNING: This will ERASE ALL DATA on $DISK"
                      read -rp "Type 'YES' to continue: " CONFIRM
                      if [ "$CONFIRM" != "YES" ]; then
                        echo "Aborted."
                        exit 1
                      fi

                      # --- WIPE EXISTING SIGNATURES ---
                      echo "Wiping filesystem signatures..."
                      wipefs --all "$DISK"

                      # --- CREATE PARTITIONS ---
                      echo "Creating GPT partition table..."
                      parted -s "$DISK" mklabel gpt

                      echo "Creating EFI partition..."
                      parted -s "$DISK" mkpart primary fat32 1MiB "$BOOT_SIZE"
                      parted -s "$DISK" set 1 esp on
                      parted -s "$DISK" name 1 "$BOOT_LABEL"

                      echo "Creating root partition..."
                      parted -s "$DISK" mkpart primary ext4 "$BOOT_SIZE" 100%
                      parted -s "$DISK" name 2 "$ROOT_LABEL"

                      # --- FORMAT PARTITIONS ---
                      EFI_PART="''${DISK}1"
                      ROOT_PART="''${DISK}2"

                      # Adjust naming for NVMe drives (nvme0n1p1 etc.)
                      if [[ "$DRIVE" == nvme* ]]; then
                        EFI_PART="''${DISK}p1"
                        ROOT_PART="''${DISK}p2"
                      fi

                      echo "Formatting EFI partition as FAT32..."
                      mkfs.fat -F 32 -n "$BOOT_LABEL" "$EFI_PART"

                      echo "Formatting root partition as ext4..."
                      mkfs.ext4 -L "$ROOT_LABEL" "$ROOT_PART"

                      # --- MOUNT PARTITIONS ---
                      echo "Mounting partitions..."
                      sleep 10
                      mkdir -p /mnt/nixos
                      mount /dev/disk/by-label/''${ROOT_LABEL} /mnt/nixos

                      mkdir -p /mnt/nixos/boot
                      mount /dev/disk/by-label/''${BOOT_LABEL} /mnt/nixos/boot
                      echo
                      echo "Done!"
                      echo "Partitions created and mounted as:"
                      lsblk "$DISK"
                      echo
                      echo "Mounted at /mnt/nixos and /mnt/nixos/boot"

                      # --- INSTALL NIXOS ---
                      echo
                      echo "Installing NixOS profile..."
                      nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixpkgs
                      nix-channel --add https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz home-manager
                      nix-channel --update
                      nixos-generate-config --root /mnt/nixos
                      sudo -u andrew bash <<'EOF'
                      cd /data/andrew
                      # ^^^^ TODO remove branch
                      git clone --branch dev/orin https://github.com/goromal/anixpkgs.git
                      cp /mnt/nixos/etc/nixos/hardware-configuration.nix anixpkgs/pkgs/nixos/hardware/temp.nix
                      cp anixpkgs/pkgs/nixos/configurations/jetpack-orin-nx.nix anixpkgs/pkgs/nixos/configurations/jetpack-temp.nix
                      sed -i 's/orin-nx/temp/g' anixpkgs/pkgs/nixos/configurations/jetpack-temp.nix
                      sed -i 's/machines\.base\.nixosState *= *"[^"]*"/machines.base.nixosState = "${nixos-version}"/' anixpkgs/pkgs/nixos/configurations/jetpack-temp.nix
                      mkdir -p ~/.config/nixpkgs
                      echo "{ allowUnfree = true; }" > ~/.config/nixpkgs/config.nix
                      EOF
                      mkdir -p /root/.config/nixpkgs
                      cp /data/andrew/.config/nixpkgs/config.nix /root/.config/nixpkgs
                      rm /mnt/nixos/etc/nixos/*
                      ln -s /data/andrew/anixpkgs/pkgs/nixos/configurations/jetpack-temp.nix /mnt/nixos/etc/nixos/configuration.nix
                      nixos-install --root /mnt/nixos
                      echo "Done! Please shutdown and reboot, then proceed with the anix-init command while connected to the internet."
                    '')
                  ];
                }
              )
            ];
          };
      };
    };
}
