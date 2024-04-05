# devshell

Developer tool for creating siloed dev environments.

```
usage: devshell [-d DEVRC] [--run CMD] workspace_name

Enter [workspace_name]'s development shell as defined in ~/.devrc
(can specify an alternate path with -d DEVRC).
Optionally run a one-off command with --run CMD (e.g., --run interact).

Example ~/.devrc:
=================================================================
dev_dir = ~/dev
data_dir = ~/data
pkgs_dir = ~/sources/anixpkgs
pkgs_var = <anixpkgs>

# repositories
[manif-geom-cpp] = pkgs manif-geom-cpp
[geometry] = pkgs python3.pkgs.geometry
[pyvitools] = git@github.com:goromal/pyvitools.git
[scrape] = git@github.com:goromal/scrape.git

# workspaces
signals = manif-geom-cpp geometry pyvitools
=================================================================

```

A workspace has the directory tree structure:

- `[dev_dir]/[workspace_name]`: Workspace root.
  - `data/`: Directory for storing long-lived workspace data, symlinked to `[data_dir]/[workspace_name]`.
  - `.envrc`: `direnv` environment file defining important worksapce aliases.
  - `shell.nix`: Workspace shell file for `lorri` integrations.
  - `sources/`: Directory containing all workspace source repositories.

The `dev/` directory can be deleted and re-constructed as needed, whereas the `data/` directory holds stuff that's meant to last.

Once in the shell, the following commands are provided:

- `setupcurrentws`: A wrapped version of [setupws](./setupws.md) that will build your development workspace as specified in `~/.devrc`.
- `godev`: An alias that will take you to the root of your development workspace.
- `listsources`: See the [listsources](./listsources.md) tool documentation.
- `interact`: Enter an interactive menu for workspace source manipulation.

