---
name: anixpkgs-deploy
description: Use when making or deploying changes to NixOS configuration or any anixpkgs package/module. Covers the edit-deploy-test workflow and common gotchas.
---

This machine runs NixOS. All system configuration lives in the `anixpkgs` repo, cloned at `~/sources/anixpkgs` (canonical) and possibly also at another path (e.g. `/data/andrew/dev/claude/sources/anixpkgs`). `/etc/nixos/configuration.nix` is symlinked into `~/sources/anixpkgs`.

## Workflow

1. **Edit** the relevant Nix module or Python/shell script under `pkgs/` in the anixpkgs repo being worked on.
2. **Stage new files** — `git-cc` (used internally by `anix-upgrade`) only copies tracked files (`git ls-files`). New files must be `git add`-ed before running `anix-upgrade`, or they will be silently absent from the build.
3. **Deploy** — prefer the local `anix-upgrade-ui` API; fall back to CLI only if the API is not reachable:

   **API (preferred):** Check availability, then POST with the source path:
   ```bash
   curl -si http://localhost/anix-upgrade/api/v1/run -X POST \
     -H 'Content-Type: application/json' \
     -d '{"source": "/path/to/anixpkgs", "local": true}'
   # HTTP 202 → {"run_id": "<uuid>", "started": true}
   # HTTP 409 → upgrade already in progress
   ```
   Then stream live output until `[UPGRADE SUCCESSFUL]` or `[UPGRADE FAILED]`:
   ```bash
   curl -N http://localhost/anix-upgrade/api/v1/stream/<run_id>
   ```

   **CLI fallback** (only if API returns non-2xx or connection refused):
   ```bash
   anix-upgrade --local -s /path/to/anixpkgs
   ```
   `--local` builds and switches immediately. `-s` points at the source tree.

4. **Test** the result on this machine before committing.

## Important gotchas

- NixOS modules must be **imported** in the right place (e.g. `pc-base.nix` imports list) to take effect — adding a file is not enough.
- New options must be declared in `pkgs/nixos/components/opts.nix` and assigned in `pc-base.nix` before they can be used in components like `base-dev-pkgs.nix`.
- MCP servers are registered per-user via `claude mcp add -s user ...`; the `claude-setup` script (in `base-dev-pkgs.nix`) handles this and must be re-run after a new server is added to propagate the registration.

## Triggering and monitoring upgrades via the API

Any machine running `anix-upgrade-ui` exposes a REST API — reachable at `http://localhost/anix-upgrade/api/v1/` on the local machine, or `http://<hostname>.local/anix-upgrade/api/v1/` for other LAN machines. No auth is required.

### Trigger an upgrade

For **local source builds** (working directory changes, not yet committed), pass `"source"` — no push needed:
```bash
curl -si -X POST http://localhost/anix-upgrade/api/v1/run \
  -H 'Content-Type: application/json' \
  -d '{"source": "/path/to/anixpkgs", "local": true}'
```

For **remote machines fetching from GitHub**, the commit must be pushed first. **Prefer a full commit hash over a branch name** — branch tarballs are CDN-cached and may be stale for minutes after a push; a commit hash uses `fetchGit` with a content-addressed `rev` and bypasses caching:

**Prefer a full commit hash over a branch name.** Branch tarballs (`archive/refs/heads/…`) are served by GitHub's CDN, which has its own TTL and may return stale content for minutes after a push — even with `--tarball-ttl 0`. A commit hash uses `fetchGit` with a content-addressed `rev`, so GitHub must return that exact commit; no CDN caching can interfere.

```bash
# Reliable — content-addressed, no CDN delay:
curl -si -X POST http://<hostname>.local/anix-upgrade/api/v1/run \
  -H 'Content-Type: application/json' \
  -d "{\"commit\": \"$(git rev-parse HEAD)\", \"local\": true}"

# Convenient but may get stale CDN content for a few minutes after push:
curl -si -X POST http://<hostname>.local/anix-upgrade/api/v1/run \
  -H 'Content-Type: application/json' \
  -d '{"branch": "dev/my-feature", "local": true}'

# HTTP 202 → {"run_id": "<uuid>", "started": true}
# HTTP 409 → upgrade already in progress
```

Use `-si` (not `-s`) so the response headers are visible — some network proxies strip JSON body values when using `-s` alone.

JSON body fields (all optional): `version`, `commit`, `branch`, `source` (local path), `local` (bool), `boot` (bool). Same semantics as `anix-upgrade` flags.

> **`"local": true` is required when the branch/commit modifies any service package or NixOS module.** Without it, `anix-upgrade` leaves `dependencies.nix` set to `local-build = false`, so module package defaults (e.g. `cfg.package`) resolve to the **published tag** binary rather than the branch binary — service code changes silently don't take effect. `"local": true` causes `anix-upgrade` to patch `dependencies.nix` so modules use packages from the fetched source tree.

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
