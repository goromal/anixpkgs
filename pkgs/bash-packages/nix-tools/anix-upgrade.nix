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
    transaction_started=0
    upgrade_complete=0
    restore_source() {
      if [[ "$transaction_started" == "0" ]]; then
        return
      fi
      rm -rf anixpkgs
      if [[ "$previous_kind" == "symlink" ]]; then
        ${printYellow} "Restoring previous anixpkgs symlink."
        ln -s "$prev_symlink" anixpkgs
      elif [[ "$previous_kind" == "directory" ]]; then
        ${printYellow} "Restoring previous anixpkgs directory."
        mv "$fromdir" anixpkgs
      fi
      transaction_started=0
    }
    cleanup() {
      status=$?
      trap - EXIT HUP INT TERM
      if [[ "$upgrade_complete" == "0" ]]; then
        restore_source
      fi
      rm -rf "$tmpdir"
      exit "$status"
    }
    trap cleanup EXIT
    trap 'exit 130' HUP INT TERM

    sources_dir="$HOME/sources"
    if [[ ! -d "$sources_dir" ]]; then
      ${printError} "Source directory does not exist: $sources_dir"
      exit 1
    fi
    if ! cd "$sources_dir"; then
      ${printError} "Could not enter source directory: $sources_dir"
      exit 1
    fi
    if [[ -n "$source" && "$source" != /* ]]; then
      ${printError} "Please provide an absolute path to the source tree."
      exit 1
    fi
    if [[ -n "$source" && ! -d "$source" ]]; then
      ${printError} "Source tree does not exist: $source"
      exit 1
    fi
    if [[ -n "$source" && -d anixpkgs && ! -L anixpkgs \
      && "$(realpath "$source")" == "$(realpath anixpkgs)" ]]; then
      ${printError} "The source tree cannot also be the managed $sources_dir/anixpkgs directory."
      exit 1
    fi
    ${
      if standalone then
        ''
          home_config="''${XDG_CONFIG_HOME:-$HOME/.config}/home-manager/home.nix"
          if [[ ! -f "$home_config" ]]; then
            ${printError} "Home Manager configuration does not exist: $home_config"
            exit 1
          fi
        ''
      else
        ""
    }

    if [[ -f "$HOME/.anix-version" ]]; then
      vcurr=$(cat "$HOME/.anix-version")
    else
      vcurr="unknown"
    fi
    if [[ "$vcurr" != "Local Build"* ]]; then
      vcurr=''${vcurr#v}
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
    if [[ -e anixpkgs || -L anixpkgs ]]; then
      if [[ -L anixpkgs ]]; then
        ${printYellow} "Removing existing symlink."
        previous_kind="symlink"
        prev_symlink=$(readlink anixpkgs)
        fromdir="$prev_symlink"
        transaction_started=1
        rm anixpkgs
      elif [[ -d anixpkgs ]]; then
        ${printYellow} "Removing existing directory."
        previous_kind="directory"
        if ! cp -a anixpkgs "$tmpdir"; then
          ${printError} "Could not back up the existing anixpkgs directory."
          exit 1
        fi
        fromdir="$tmpdir/anixpkgs"
        transaction_started=1
        rm -rf anixpkgs
      else
        ${printError} "$sources_dir/anixpkgs exists but is not a directory or symlink."
        exit 1
      fi
    else
      transaction_started=1
    fi
    if [[ -n "$version" ]]; then
      nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/tags/v'"''${version}"'"; }' -o anixpkgs
    elif [[ -n "$commit" ]]; then
      nix-build -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "'"$commit"'"; }' -o anixpkgs
    elif [[ -n "$branch" ]]; then
      nix-build --tarball-ttl 0 -E 'with (import (fetchTarball "https://github.com/goromal/anixpkgs/archive/refs/heads/master.tar.gz") {}); pkgsSource { local = '"$localVar"'; ref = "refs/heads/'"$branch"'"; }' -o anixpkgs
    elif [[ -n "$source" ]]; then
      if ! ${git-cc}/bin/git-cc "$source" anixpkgs; then
        ${printError} "Could not copy source tree: $source"
        exit 1
      fi
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
    if [[ ! -f anixpkgs/NIXOS_VERSION ]]; then
      ${printError} "Selected source tree has no NIXOS_VERSION."
      exit 1
    fi
    nixos_dest=$(cat anixpkgs/NIXOS_VERSION)
    rebuild_mode="channels"
    if [[ -f anixpkgs/NIXOS_REBUILD_MODE ]]; then
      read -r rebuild_mode < anixpkgs/NIXOS_REBUILD_MODE
    fi
    if [[ "$rebuild_mode" != "flake" && "$rebuild_mode" != "channels" ]]; then
      ${printError} "Unsupported rebuild mode: $rebuild_mode"
      exit 1
    fi
    ${
      if standalone == false then
        ''
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
        ''
          prepare_home_rebuild() {
            if [[ "$rebuild_mode" == "flake" ]]; then
              if ! system=$(nix eval --impure --raw --expr builtins.currentSystem); then
                ${printError} "Could not determine the current Nix system."
                return 1
              fi
              if ! target_nixpkgs=$(
                nix eval --raw "$HOME/sources/anixpkgs#legacyPackages.$system.path"
              ); then
                ${printError} "Could not evaluate the target Nixpkgs revision."
                return 1
              fi
              home_rebuild=(nix run "$HOME/sources/anixpkgs#home-manager" -- switch -f "$home_config")
            else
              if ! command -v home-manager >/dev/null; then
                ${printError} "The installed home-manager command is required for this legacy target."
                return 1
              fi
              target_nixpkgs=""
              home_rebuild=(home-manager switch -f "$home_config")
            fi
          }
        ''
    }
    ${printYellow} "Upgrading anixpkgs from $vcurr -> $vdest (${
      if standalone then "Home Manager" else "NixOS"
    } $nixos_dest)..."
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
            if prepare_home_rebuild \
              && NIX_PATH="''${target_nixpkgs:+nixpkgs=$target_nixpkgs:}''${NIX_PATH:-}" \
              "''${home_rebuild[@]}"; then
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
            if prepare_home_rebuild \
              && NIX_PATH="''${target_nixpkgs:+nixpkgs=$target_nixpkgs:}''${NIX_PATH:-}" \
              "''${home_rebuild[@]}"; then
              ${printYellow} "Done."
              build_success=1
            fi
          ''
      }
    fi
    if [[ "$build_success" == "0" ]]; then
      ${printError} "Build/switch failed."
      exit 1
    fi
    echo ""
    if [[ -n "$fromdir" ]]; then
      ${anix-changelog-compare}/bin/anix-changelog-compare "$fromdir" anixpkgs
    else
      ${printYellow} "No prior anixpkgs tree found; skipping changelog compare."
    fi
    upgrade_complete=1
    echo "ANIX-UPGRADE_STATUS=SUCCESS"
  ''
)
// {
  meta = {
    inherit description;
    longDescription = "";
    autoGenUsageCmd = "--help";
  };
}
