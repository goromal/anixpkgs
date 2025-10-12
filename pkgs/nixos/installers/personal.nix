{ config, pkgs, lib, ... }:
with import ../dependencies.nix; {
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
    # Provide an initial copy of the NixOS channel so that the user
    # doesn't need to run "nix-channel --update" first.
    <nixpkgs/nixos/modules/installer/cd-dvd/channel.nix>
    ../profiles/personal.nix
  ];
  networking.wireless.enable = lib.mkForce false;
  machines.base.nixosState = nixos-version;

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
        echo "❌ Error: $DISK does not exist."
        exit 1
      fi

      echo "⚠️  This will ERASE ALL DATA on $DISK"
      read -rp "Type 'YES' to continue: " CONFIRM
      if [ "$CONFIRM" != "YES" ]; then
        echo "Aborted."
        exit 1
      fi

      # --- WIPE EXISTING SIGNATURES ---
      echo "🧽 Wiping filesystem signatures..."
      wipefs --all "$DISK"

      # --- CREATE PARTITIONS ---
      echo "📦 Creating GPT partition table..."
      parted -s "$DISK" mklabel gpt

      echo "🪣 Creating EFI partition..."
      parted -s "$DISK" mkpart primary fat32 1MiB "$BOOT_SIZE"
      parted -s "$DISK" set 1 esp on
      parted -s "$DISK" name 1 "$BOOT_LABEL"

      echo "🧱 Creating root partition..."
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

      echo "🪵 Formatting EFI partition as FAT32..."
      mkfs.fat -F 32 -n "$BOOT_LABEL" "$EFI_PART"

      echo "🌲 Formatting root partition as ext4..."
      mkfs.ext4 -L "$ROOT_LABEL" "$ROOT_PART"

      # --- MOUNT PARTITIONS ---
      echo "📂 Mounting partitions..."
      sleep 10
      mkdir -p /mnt/nixos
      mount /dev/disk/by-label/''${ROOT_LABEL} /mnt/nixos

      mkdir -p /mnt/nixos/boot
      mount /dev/disk/by-label/''${BOOT_LABEL} /mnt/nixos/boot
      echo
      echo "✅ Done!"
      echo "Partitions created and mounted as:"
      lsblk "$DISK"
      echo
      echo "Mounted at /mnt/nixos and /mnt/nixos/boot"

      # --- INSTALL NIXOS ---
      echo
      echo "💻 Installing NixOS profile..."
      nix-channel --add https://nixos.org/channels/nixos-${nixos-version} nixpkgs
      nix-channel --add https://github.com/nix-community/home-manager/archive/release-${nixos-version}.tar.gz home-manager
      nix-channel --update
      nixos-generate-config --root /mnt/nixos
      sudo -u andrew bash <<'EOF'
      cd /data/andrew
      git clone --branch dev/machine-directions https://github.com/goromal/anixpkgs.git
      cp /mnt/nixos/etc/nixos/hardware-configuration.nix anixpkgs/pkgs/nixos/hardware/temp.nix
      cp anixpkgs/pkgs/nixos/configurations/personal-inspiron.nix anixpkgs/pkgs/nixos/configurations/personal-temp.nix
      sed -i 's/inspiron/temp/g' anixpkgs/pkgs/nixos/configurations/personal-temp.nix
      sed -i 's/machines\.base\.nixosState *= *"[^"]*"/machines.base.nixosState = "${nixos-version}"/' anixpkgs/pkgs/nixos/configurations/personal-temp.nix
      mkdir -p ~/.config/nixpkgs
      echo "{ allowUnfree = true; }" > ~/.config/nixpkgs/config.nix
      EOF
      mkdir -p /root/.config/nixpkgs
      cp /data/andrew/.config/nixpkgs/config.nix /root/.config/nixpkgs
      rm /mnt/nixos/etc/nixos/*
      ln -s /data/andrew/anixpkgs/pkgs/nixos/configurations/personal-temp.nix /mnt/nixos/etc/nixos/configuration.nix
      nixos-install --root /mnt/nixos
      echo "✅ Done!"
    '') # ^^^^ TODO remove that dev/machine-directions branch
  ];
}
# NIXPKGS_ALLOW_UNFREE=1 nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -I nixos-config=pkgs/nixos/installers/personal.nix
