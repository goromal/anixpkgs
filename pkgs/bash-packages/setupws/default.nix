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
    readonly CLAUDE_TARGET_DIR="$PWD/data/.claude"
    readonly CLAUDE_LINK_LOCATIONS=(
      ".claude"
      "sources/.claude"
    )
    mkdir -p "$CLAUDE_TARGET_DIR"
    for link_path in "''${CLAUDE_LINK_LOCATIONS[@]}"; do
      if [ -L "$link_path" ] && [ "$(readlink "$link_path")" == "$CLAUDE_TARGET_DIR" ]; then
        continue
      fi
      if [ -e "$link_path" ]; then
        mv -- "$link_path" "$CLAUDE_TARGET_DIR/"
      fi
      mkdir -p "$(dirname "$link_path")"
      ln -sf -- "$CLAUDE_TARGET_DIR" "$link_path"
    done
    if [ ! -f "$CLAUDE_TARGET_DIR/CLAUDE.md" ]; then
      cat > "$CLAUDE_TARGET_DIR/CLAUDE.md" << 'CLAUDEMD'
# Claude Workspace Configuration

## Task Management with Beads

This workspace uses [beads](https://github.com/steveyegge/beads) for task tracking and management. Beads is a distributed, git-backed graph issue tracker designed specifically for AI agents.

### For Claude Code

**IMPORTANT**: When working in this workspace, you MUST use `bd` (beads) commands for task management instead of the TodoWrite tool.

#### Setup

The beads daemon is automatically managed:
- **Auto-starts** when you enter the devshell
- **Auto-stops** when you exit the devshell
- **Manual control** (if needed):
  - Start: `bd daemon start`
  - Status: `bd daemon status`
  - Stop: `bd daemon stop`

#### Task Management Commands

- **Create a new task**: `bd add "Task description"`
- **List tasks**: `bd ls` or `bd list`
- **Show task details**: `bd show <task-id>`
- **Update task status**: `bd status <task-id> <status>` (e.g., `bd status bd-a1b2 in-progress`)
- **Mark task complete**: `bd done <task-id>`
- **Add subtask**: `bd add "Subtask" --parent <parent-id>`
- **Set dependencies**: `bd dep <task-id> <dependency-id>`

#### Workflow

1. At the start of a complex task, run `bd ls` to see existing tasks
2. Create new tasks with `bd add "Task description"`
3. Update task status as you work: `bd status <task-id> in-progress`
4. Mark tasks complete when done: `bd done <task-id>`
5. For complex features, create parent tasks and subtasks with dependencies

#### Status Values

- `pending` - Task not yet started
- `in-progress` - Currently working on
- `completed` - Task finished
- `blocked` - Task blocked by dependencies or issues

### Notes

- All beads data is stored in `.beads/` (symlinked to `data/.beads/`)
- Beads integrates with git for version control
- The VSCode beads extension provides a visual kanban interface
- The beads daemon must be running for the VSCode extension to work
CLAUDEMD
    fi

    if [[ ! -d sources ]]; then
        mkdir sources
    fi

    readonly BEADS_TARGET_DIR="$PWD/data/.beads"
    readonly BEADS_LINK_LOCATIONS=(
      "sources/.beads"
    )
    mkdir -p "$BEADS_TARGET_DIR"
    for link_path in "''${BEADS_LINK_LOCATIONS[@]}"; do
      if [ -L "$link_path" ] && [ "$(readlink "$link_path")" == "$BEADS_TARGET_DIR" ]; then
        continue
      fi
      if [ -e "$link_path" ]; then
        mv -- "$link_path" "$BEADS_TARGET_DIR/"
      fi
      mkdir -p "$(dirname "$link_path")"
      ln -sf -- "$BEADS_TARGET_DIR" "$link_path"
    done

    readonly BEADS_CONFIG_TARGET="$PWD/data/.beads.yml"
    readonly BEADS_CONFIG_LINK="sources/.beads.yml"
    if [ -e "$BEADS_CONFIG_LINK" ] && [ ! -L "$BEADS_CONFIG_LINK" ]; then
      mv -- "$BEADS_CONFIG_LINK" "$BEADS_CONFIG_TARGET"
    fi
    if [ ! -d "$BEADS_TARGET_DIR/dolt" ]; then
      if command -v bd &> /dev/null; then
        cd "$dev_ws_dir/sources"
        bd init 2>/dev/null || true
        cd "$dev_ws_dir"
      fi
    fi

    # Create symlink for config if it exists in sources or data
    if [ -f "$dev_ws_dir/sources/.beads.yml" ] && [ ! -L "$dev_ws_dir/sources/.beads.yml" ]; then
      mv "$dev_ws_dir/sources/.beads.yml" "$BEADS_CONFIG_TARGET"
    fi
    if [ -f "$BEADS_CONFIG_TARGET" ] && [ ! -L "$BEADS_CONFIG_LINK" ]; then
      ln -sf -- "$BEADS_CONFIG_TARGET" "$BEADS_CONFIG_LINK"
    elif [ ! -f "$BEADS_CONFIG_TARGET" ] && [ -d "$BEADS_TARGET_DIR/dolt" ]; then
      # Beads initialized but no config file - create a minimal one
      touch "$BEADS_CONFIG_TARGET"
      ln -sf -- "$BEADS_CONFIG_TARGET" "$BEADS_CONFIG_LINK"
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
