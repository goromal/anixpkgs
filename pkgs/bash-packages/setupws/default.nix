{ writeArgparseScriptBin, color-prints }:
let
  default-dev-dir = "~/dev";
  default-data-dir = "~/data";
  usage_str = ''
    usage: setupws [OPTIONS] workspace_name srcname:git_url [srcname:git_url ...] [scriptname=scriptpath ...]

    Create a development workspace with specified git sources and scripts.

    Options:
        --dev_dir [DIRNAME]        Specify the root directory where the [workspace_name] source
                                   directory will be created (default: ${default-dev-dir})

        --data_dir [DIRNAME]       Specify the root directory where the [workspace_name] mutable 
                                   data will be stored (default: ${default-data-dir})
  '';
  printCyn = "${color-prints}/bin/echo_cyan";
  printErr = "${color-prints}/bin/echo_red";
  printYlw = "${color-prints}/bin/echo_yellow";
  printGrn = "${color-prints}/bin/echo_green";
in
(writeArgparseScriptBin "setupws" usage_str
  [
    {
      var = "dev_dir";
      isBool = false;
      default = default-dev-dir;
      flags = "--dev_dir";
    }
    {
      var = "data_dir";
      isBool = false;
      default = default-data-dir;
      flags = "--data_dir";
    }
  ]
  ''
    set -euo pipefail

    write_if_changed() {
      local target="$1"
      local contents="$2"
      if [[ ! -f "$target" ]] || [[ "$(<"$target")" != "$contents" ]]; then
        printf '%s\n' "$contents" > "$target"
        return 0
      fi
      return 1
    }

    wsname=$1
    if [[ -z "$wsname" ]]; then
        ${printErr} "ERROR: no workspace name provided."
        exit 1
    fi

    ${printCyn} "Setting up workspace $wsname..."
    dev_ws_dir=$dev_dir/$wsname
    data_ws_dir=$data_dir/$wsname

    mkdir -p $dev_ws_dir
    mkdir -p $data_ws_dir

    cd $dev_ws_dir

    if [[ ! -d data ]]; then
        ln -s $data_ws_dir data
    fi
    readonly TARGET_DIR="$PWD/data/.claude"
    readonly LINK_LOCATIONS=(
      ".claude"
      "sources/.claude"
    )
    mkdir -p "$TARGET_DIR"
    for link_path in "''${LINK_LOCATIONS[@]}"; do
      if [ -L "$link_path" ] && [ "$(readlink "$link_path")" == "$TARGET_DIR" ]; then
        continue
      fi
      if [ -e "$link_path" ]; then
        mv -- "$link_path" "$TARGET_DIR/"
      fi
      mkdir -p "$(dirname "$link_path")"
      ln -sf -- "$TARGET_DIR" "$link_path"
    done
    if [[ ! -f "$TARGET_DIR/CLAUDE.md" ]]; then
      touch "$TARGET_DIR/CLAUDE.md"
    fi
    if [[ ! -d sources ]]; then
        mkdir sources
    fi

    envrc_contents=$(printf '%s\n' \
      "export WSROOT=$dev_ws_dir" \
      'eval "$(lorri direnv)"' \
      'if [[ -n "''${DEVSHELL_RUNTIME_BIN:-}" ]]; then PATH_add "$DEVSHELL_RUNTIME_BIN"; fi' \
      'PATH_add $WSROOT/.bin')
    envrc_changed=0
    if write_if_changed .envrc "$envrc_contents"; then
      envrc_changed=1
    fi
    if [[ ! -f shell.nix ]]; then
      lorri init
    fi
    if [[ "$envrc_changed" == "1" ]]; then
      direnv allow
    fi

    pushd data
    data_envrc_contents=$(printf '%s\n' \
      "export WSROOT=$dev_ws_dir" \
      'PATH_add $WSROOT/.bin')
    if write_if_changed .envrc "$data_envrc_contents"; then
      direnv allow
    fi
    popd

    cd sources

    next_bin_dir=$(mktemp -d "$dev_ws_dir/.bin.next.XXXXXX")
    cleanup_next_bin() {
      if [[ -n "$next_bin_dir" ]]; then
        rm -rf "$next_bin_dir"
      fi
    }
    trap cleanup_next_bin EXIT

    for i in ''${@:2}; do
        if [[ "$i" == *"="* ]]; then
            scriptalias="''${i%%=*}"
            scriptpath="''${i#*=}"
            if [[ ! -f "$scriptpath" ]]; then
                ${printYlw} "Script $scriptpath not found; skipping."
                continue
            fi
            if [[ ! -x "$scriptpath" ]]; then
              ${printYlw} "Script $scriptpath not executable; skipping."
              continue
            fi
            cp "$scriptpath" "$next_bin_dir/$scriptalias"
        else
            reponame="''${i%%:*}"
            repourl="''${i#*:}"
            if [[ ! -d $reponame ]]; then
                ${printGrn} "Cloning and setting up $reponame..."
                git clone --filter=blob:none --recurse-submodules "$repourl" "$reponame"
            else
                ${printGrn} "Repo $reponame present."
            fi
        fi
    done

    if [[ ! -d ../.bin ]] || ! diff -qr ../.bin "$next_bin_dir" >/dev/null; then
      ${printGrn} "Updating workspace scripts..."
      rm -rf ../.bin
      mv "$next_bin_dir" ../.bin
      next_bin_dir=""
    fi

    ${printGrn} "Done"
  ''
)
// {
  meta = {
    description = "Create standalone development workspaces.";
    longDescription = ''
      Unlike with [devshell](./devshell.md)'s `setupcurrentws` command, this tool takes all of its setup info from the CLI.
    '';
    autoGenUsageCmd = "--help";
  };
}
