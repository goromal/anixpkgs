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

## Triggering and monitoring upgrades on remote machines

Each machine running `anix-upgrade-ui` exposes a REST API reachable via mDNS at `http://<hostname>.local/anix-upgrade/api/v1/`. No auth is required (LAN-only).

### Trigger an upgrade

**The branch must be pushed to GitHub first.** `anix-upgrade` fetches it as a tarball from GitHub; local-only commits are invisible to the remote machine.

```bash
curl -si -X POST http://<hostname>.local/anix-upgrade/api/v1/run \
  -H 'Content-Type: application/json' \
  -d '{"branch": "dev/my-feature", "local": true}'
# HTTP 202 → {"run_id": "<uuid>", "started": true}
# HTTP 409 → upgrade already in progress
```

Use `-si` (not `-s`) so the response headers are visible — some network proxies strip JSON body values when using `-s` alone.

JSON body fields (all optional): `version`, `commit`, `branch`, `source` (local path), `local` (bool), `boot` (bool). Same semantics as `anix-upgrade` flags.

> **`"local": true` is required when the branch modifies any service package or NixOS module.** Without it, `anix-upgrade` leaves `dependencies.nix` set to `local-build = false`, so all module package defaults (e.g. `cfg.package`) resolve to the **published tag** binary rather than the branch binary — service code changes silently don't take effect. `"local": true` causes `anix-upgrade` to patch `dependencies.nix` so modules use packages from the branch source tree.

> **Note on tarball caching:** `anix-upgrade` passes `--tarball-ttl 0` for branch builds so GitHub tarballs are always fetched fresh. This requires `andrew` to be a Nix trusted user — guaranteed on any machine with `anix-upgrade-ui` enabled (the module sets it). Without this, the Nix daemon silently ignores `--tarball-ttl 0` and may build from a stale cached tarball.

### Poll for completion

```bash
curl -s http://<hostname>.local/anix-upgrade/api/v1/status/<run_id> | jq .
# → {"run_id": "...", "status": "running"|"success"|"failed", "running": bool,
#    "returncode": int|null, "started_at": "...", "finished_at": "...", ...}
# Returns 404 if the run_id has been superseded by a newer run.
```

Poll until `status` is `success` or `failed`. A `run_id` becomes stale (404) once a subsequent run starts on that machine, so download the log before triggering another upgrade.

### Stream live output (SSE)

```bash
curl -N http://<hostname>.local/anix-upgrade/api/v1/stream/<run_id>
# Replays the last 512 KB of log, then follows live output.
# Final lines: [UPGRADE SUCCESSFUL] or [UPGRADE FAILED (exit N)], then [DONE].
```

### Download the full log

```bash
curl -o upgrade.log http://<hostname>.local/anix-upgrade/api/v1/log/<run_id>
# Returns 404 if run_id is stale.
```

### Observability

- API-triggered upgrades appear in the browser UI at `http://<hostname>.local/anix-upgrade/` with a **via API** badge.
- They block manual UI upgrades (and vice versa) — only one run at a time per machine.
- The UI streams the same log output whether the run was triggered locally or via API.
