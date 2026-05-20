---
name: anixpkgs-deploy
description: Use when making or deploying changes to NixOS configuration or any anixpkgs package/module. Covers the edit-deploy-test workflow and common gotchas.
---

This machine runs NixOS. All system configuration lives in the `anixpkgs` repo, cloned at `~/sources/anixpkgs` (canonical) and possibly also at another path (e.g. `/data/andrew/dev/claude/sources/anixpkgs`). `/etc/nixos/configuration.nix` is symlinked into `~/sources/anixpkgs`.

## Workflow

1. **Edit** the relevant Nix module or Python/shell script under `pkgs/` in the anixpkgs repo being worked on.
2. **Stage new files** — `git-cc` (used internally by `anix-upgrade`) only copies tracked files (`git ls-files`). New files must be `git add`-ed before running `anix-upgrade`, or they will be silently absent from the build.
3. **Deploy** with:
   ```
   anix-upgrade --local -s /path/to/anixpkgs
   ```
   `--local` builds and switches immediately without fetching a remote version.
   `-s` points at the source tree to use (required when editing a non-canonical clone).
4. **Test** the result on this machine before committing.

## Important gotchas

- NixOS modules must be **imported** in the right place (e.g. `pc-base.nix` imports list) to take effect — adding a file is not enough.
- New options must be declared in `pkgs/nixos/components/opts.nix` and assigned in `pc-base.nix` before they can be used in components like `base-dev-pkgs.nix`.
- MCP servers are registered per-user via `claude mcp add -s user ...`; the `claude-setup` script (in `base-dev-pkgs.nix`) handles this and must be re-run after a new server is added to propagate the registration.
