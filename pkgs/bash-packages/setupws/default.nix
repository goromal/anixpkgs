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
    touch "$TARGET_DIR/CLAUDE.md"
    if [[ ! -d sources ]]; then
        mkdir sources
    fi
    if [[ -d .bin ]]; then
        rm -rf .bin
    fi
    mkdir .bin

    echo "export WSROOT=$dev_ws_dir" > .envrc
    lorri init
    echo 'eval "$(lorri direnv)"' >> .envrc
    echo 'PATH_add $WSROOT/.bin' >> .envrc
    direnv allow

    pushd data
    echo "export WSROOT=$dev_ws_dir" > .envrc
    echo 'PATH_add $WSROOT/.bin' >> .envrc
    direnv allow
    popd

    cd sources

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
            ${printGrn} "Adding script $scriptpath..."
            cp "$scriptpath" ../.bin/$scriptalias
        else
            reponame="''${i%%:*}"
            repourl="''${i#*:}"
            if [[ ! -d $reponame ]]; then
                ${printGrn} "Cloning and setting up $reponame..."
                git clone --recurse-submodules "$repourl" "$reponame"
            else
                ${printGrn} "Repo $reponame present."
            fi
        fi
    done

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
