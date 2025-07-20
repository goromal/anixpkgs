# pkgshell

Flexible Nix shell.


## Usage

```bash
usage: pkgshell [options] pkgs attr [--run CMD]

Make a nix shell with package [attr] from [pkgs] (e.g., '<nixpkgs>').
Optionally run a one-off command with --run CMD.

Special values for [pkgs]:
  anixpkgs      Fetch the latest anixpkgs from GitHub

Options:
-v|--verbose    Print verbose output.

```

