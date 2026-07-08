---
name: anixpkgs-deploy
description: Use when making or deploying changes to NixOS configuration or any anixpkgs package/module. Covers the edit-deploy-test workflow and common gotchas.
---

This machine runs NixOS; all system config lives in the `anixpkgs` repo, cloned at `~/sources/anixpkgs` (canonical) and possibly another path (e.g. `/data/andrew/dev/claude/sources/anixpkgs`). `/etc/nixos/configuration.nix` is symlinked into `~/sources/anixpkgs`.

## Workflow

1. **Edit** the relevant Nix module or Python/shell script under `pkgs/`.
2. **Stage new files** — `git-cc` (used by `anix-upgrade`) only copies tracked files (`git ls-files`). `git add` new files first, or they are silently absent from the build.
3. **Deploy** via the local `anix-upgrade-ui` API (preferred), streaming until done:
   ```bash
   curl -si http://localhost/anix-upgrade/api/v1/run -X POST \
     -H 'Content-Type: application/json' \
     -d '{"source": "/path/to/anixpkgs", "local": true}'
   # 202 → {"run_id": "<uuid>", "started": true};  409 → already running
   curl -N http://localhost/anix-upgrade/api/v1/stream/<run_id>
   # ends with [UPGRADE SUCCESSFUL] or [UPGRADE FAILED (exit N)], then [DONE]
   ```
   CLI fallback (only if the API is unreachable): `anix-upgrade --local -s /path/to/anixpkgs`.
4. **Test** the result on this machine before committing.

`"local": true` is required whenever the change touches a service package or NixOS module — without it `anix-upgrade` leaves `dependencies.nix` at `local-build = false`, so module `cfg.package` defaults resolve to the published-tag binary and the change silently doesn't take effect.

## Important gotchas

- NixOS modules must be **imported** in the right place (e.g. `pc-base.nix` imports list) — adding a file is not enough.
- New options must be declared in `pkgs/nixos/components/opts.nix` and assigned in `pc-base.nix` before use in components like `base-dev-pkgs.nix`.
- MCP servers register per-user via `claude mcp add -s user ...`; the `claude-setup` script (in `base-dev-pkgs.nix`) handles this and must be re-run after adding a server.

## Deploying to other machines / API reference

The same API runs on every machine hosting `anix-upgrade-ui`: `http://<hostname>.local/anix-upgrade/api/v1/` (no auth). `run` body fields (all optional): `version`, `commit`, `branch`, `source` (local path), `local`, `boot` — same semantics as `anix-upgrade` flags. Use `-si` so response headers show (some proxies strip `-s` JSON bodies).

For a **remote** machine, push first and **pass `commit` (a full hash), not `branch`** — branch tarballs are CDN-cached and may be stale for minutes even with `--tarball-ttl 0`; a commit hash uses content-addressed `fetchGit` and bypasses the CDN:
```bash
curl -si -X POST http://<hostname>.local/anix-upgrade/api/v1/run \
  -H 'Content-Type: application/json' \
  -d "{\"commit\": \"$(git rev-parse HEAD)\", \"local\": true}"
```

Monitor a run (`run_id` 404s once a newer run starts, so grab logs before re-triggering):
```bash
curl -s  .../api/v1/status/<run_id> | jq .   # status: running|success|failed
curl -N  .../api/v1/stream/<run_id>          # SSE: replays last 512 KB, then live
curl -o upgrade.log .../api/v1/log/<run_id>  # full log
```
Runs appear in the browser UI at `http://<hostname>.local/anix-upgrade/` with a **via API** badge; only one run per machine at a time (API and manual UI block each other).
