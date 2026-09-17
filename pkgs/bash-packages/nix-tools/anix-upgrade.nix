{
  writeArgparseScriptBin,
  anix-changelog-compare,
  color-prints,
  standalone ? false,
  git-cc,
}:
let
  pkgname = "anix-upgrade";
  description = "Upgrade the operating system and view the delta. ${
    if standalone then " [HOME-MANAGER VERSION]" else " [NIXOS VERSION]"
  }";
  long-description = ''
    usage: ${pkgname} [-v|--version VERSION;-c|--commit COMMIT;-b|--branch BRANCH;-s|--source SOURCETREE] [--local] [--boot]
  '';
  usage_str = ''
    ${long-description}
    ${description}

    The selected source tree declares its rebuild mode. Current trees use a flake configuration; older trees fall back to the legacy channel-based configuration.
  '';
  printYellow = "${color-prints}/bin/echo_yellow";
  printError = "${color-prints}/bin/echo_red";
in
(writeArgparseScriptBin pkgname usage_str
  [
    {
      var = "version";
      isBool = false;
      default = "";
      flags = "-v|--version";
    }
    {
      var = "commit";
      isBool = false;
      default = "";
      flags = "-c|--commit";
    }
    {
      var = "branch";
      isBool = false;
      default = "";
      flags = "-b|--branch";
    }
    {
      var = "source";
      isBool = false;
      default = "";
      flags = "-s|--source";
    }
    {
      var = "local";
      isBool = true;
      default = "0";
      flags = "--local";
    }
    {
      var = "boot";
      isBool = true;
      default = "0";
      flags = "--boot";
    }
  ]
  ''
    tmpdir=$(mktemp -d)
    fromdir=""
    previous_kind=""
    prev_symlink=""
    restore_source() {
      rm -rf anixpkgs
      if [[ "$previous_kind" == "symlink" ]]; then
        ${printYellow} "Restoring previous anixpkgs symlink."
        ln -s "$prev_symlink" anixpkgs
      elif [[ "$previous_kind" == "directory" ]]; then
        ${printYellow} "Restoring previous anixpkgs directory."
        mv "$fromdir" anixpkgs
      fi
    }
    cd ~/sources
    vcurr=$(cat ~/.anix-version)
    if [[ "$vcurr" != "Local Build"* ]]; then
      vcurr=''${vcurr:1}
    fi
    if [[ "$local" == "1" ]]; then
      localVar=true
    else
      localVar=false
    fi
    ${
      if standalone == false then
        ''
          if ! atsudo true 2>/dev/null; then
            ${printError} "atsudo is not configured for passwordless sudo on this machine."
            ${printError} "Ensure ~/secrets/$(hostname)/p.txt.tyz exists and is readable."
            exit 1
          fi
        ''
      else
        ""
    }
    if [[ -d anixpkgs ]]; then
      if [[ -L anixpkgs ]]; then
        ${printYellow} "Removing existing symlink."
        previous_kind="symlink"
        prev_symlink=$(readlink anixpkgs)
        fromdir="$prev_symlink"
        rm anixpkgs
      else
        ${printYellow} "Removing existing directory."
        previous_kind="directory"
        cp -r anixpkgs "$tmpdir"
        fromdir="$tmpdir/anixpkgs"
        rm -rf anixpkgs
      fi
    fi
    if [[ -n "$version" ]]; then
      nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/tags/v'"''${version}"'"; }' -o anixpkgs
    elif [[ -n "$commit" ]]; then
      nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "'"$commit"'"; }' -o anixpkgs
    elif [[ -n "$branch" ]]; then
      nix-build --tarball-ttl 0 -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/'"$branch"'"; }' -o anixpkgs
    elif [[ -n "$source" ]]; then
      if [[ "$source" != /* ]]; then
        ${printError} "Please provide an absolute path to the source tree."
        exit 1
      fi
      ${git-cc}/bin/git-cc "$source" anixpkgs
      if [[ "$localVar" == "true" ]]; then
        sed -i 's|local-build = false;|local-build = true;|g' anixpkgs/pkgs/nixos/dependencies.nix
      fi
      _meta=$(git -C "$source" rev-parse --short HEAD 2>/dev/null || echo "local")
      echo -n "$_meta" > anixpkgs/ANIX_META
    else
      nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/master"; }' -o anixpkgs
    fi
    if [[ ! -d anixpkgs ]]; then
      ${printError} "Build failed: anixpkgs directory not created."
      restore_source
      rm -rf "$tmpdir"
      exit 1
    fi
    if [[ -n "$source" ]]; then
      vdest="Local Build ($(basename "$source"))"
    elif [[ "$localVar" == "true" ]]; then
      vdest="$(cat anixpkgs/ANIX_VERSION) (local)"
    else
      vdest=$(cat anixpkgs/ANIX_VERSION)
    fi
    nixos_dest=$(cat anixpkgs/NIXOS_VERSION)
    rebuild_mode="channels"
    if [[ -f anixpkgs/NIXOS_REBUILD_MODE ]]; then
      read -r rebuild_mode < anixpkgs/NIXOS_REBUILD_MODE
    fi
    ${
      if standalone == false then
        ''
          if [[ "$rebuild_mode" != "flake" && "$rebuild_mode" != "channels" ]]; then
            ${printError} "Unsupported NixOS rebuild mode: $rebuild_mode"
            restore_source
            rm -rf "$tmpdir"
            exit 1
          fi
          if [[ "$rebuild_mode" == "channels" ]]; then
            nixos_curr=$(nixos-version 2>/dev/null | cut -d'.' -f1,2 || echo "")
            host=$(hostname)
            case "$host" in
              atorgesen-*) legacy_name="personal-''${host#atorgesen-}" ;;
              jetson-*) legacy_name="jetpack-''${host#jetson-}" ;;
              ats) legacy_name="ats-alderlake" ;;
              *) legacy_name="$host" ;;
            esac
            legacy_config="$HOME/sources/anixpkgs/pkgs/nixos/configurations/$legacy_name.nix"
            if [[ ! -f "$legacy_config" && -e /etc/nixos/configuration.nix ]]; then
              legacy_config=/etc/nixos/configuration.nix
            fi
            if [[ ! -f "$legacy_config" ]]; then
              ${printError} "No legacy configuration found for $host."
              restore_source
              rm -rf "$tmpdir"
              exit 1
            fi
            ${printYellow} "Preparing legacy channels for NixOS $nixos_dest (currently ''${nixos_curr:-unknown})..."
            if ! atsudo nix-channel --add "https://nixos.org/channels/nixos-$nixos_dest" nixpkgs \
              || ! atsudo nix-channel --add "https://nixos.org/channels/nixos-$nixos_dest" nixos \
              || ! atsudo nix-channel --add "https://github.com/nix-community/home-manager/archive/release-$nixos_dest.tar.gz" home-manager \
              || ! atsudo nix-channel --update; then
              ${printError} "Legacy channel update failed."
              restore_source
              rm -rf "$tmpdir"
              exit 1
            fi
          fi
        ''
      else
        ""
    }
    ${printYellow} "Upgrading anixpkgs from $vcurr -> $vdest (NixOS $nixos_dest)..."
    build_success=0
    if [[ "$boot" == "1" ]]; then
      ${
        if standalone == false then
          ''
            if [[ "$rebuild_mode" == "flake" ]]; then
              rebuild=(nixos-rebuild boot --flake "$HOME/sources/anixpkgs#$(hostname)" --impure)
            else
              rebuild=(nixos-rebuild boot -I "nixos-config=$legacy_config")
            fi
            if atsudo NIXPKGS_ALLOW_UNFREE=1 "''${rebuild[@]}"; then
              ${printYellow} "Reboot for changes to take effect."
              build_success=1
            fi
          ''
        else
          ''
            ${printYellow} "Ignoring boot flag for home switch"
            if home-manager switch; then
              ${printYellow} "Done."
              build_success=1
            fi
          ''
      }
    else
      ${
        if standalone == false then
          ''
            if [[ "$rebuild_mode" == "flake" ]]; then
              rebuild=(nixos-rebuild switch --flake "$HOME/sources/anixpkgs#$(hostname)" --impure)
            else
              rebuild=(nixos-rebuild switch -I "nixos-config=$legacy_config")
            fi
            if atsudo NIXPKGS_ALLOW_UNFREE=1 "''${rebuild[@]}"; then
              ${printYellow} "Done."
              build_success=1
            fi
          ''
        else
          ''
            if home-manager switch; then
              ${printYellow} "Done."
              build_success=1
            fi
          ''
      }
    fi
    if [[ "$build_success" == "0" ]]; then
      ${printError} "Build/switch failed."
      restore_source
      rm -rf "$tmpdir"
      exit 1
    fi
    echo ""
    if [[ -n "$fromdir" ]]; then
      ${anix-changelog-compare}/bin/anix-changelog-compare "$fromdir" anixpkgs
    else
      ${printYellow} "No prior anixpkgs tree found; skipping changelog compare."
    fi
    rm -rf "$tmpdir"
  ''
)
// {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
