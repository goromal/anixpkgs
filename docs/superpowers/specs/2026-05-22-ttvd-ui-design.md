# TTVD UI Design Spec

**Date:** 2026-05-22  
**Vikunja project:** TTVD UI (tasks 43, 44, 45)

## Overview

Three-part feature: package TikTokDownloader as a Nix CLI package, build a Flask web UI that uses it as a library, and wire the service into the ATS machine via nginx.

---

## Part 1: TikTokDownloader Nix Package (Vikunja task 43)

### Goal
Make the TikTokDownloader CLI available on recreational machines.

### Package definition
- Path: `pkgs/python-packages/ttvd/default.nix`
- Builder: `buildPythonPackage` (same pattern as `easy-google-auth`)
- Source: GitHub repo (`JoeanAmier/TikTokDownloader`) pulled in as a flake input `ttvd-src` in `flake.nix`
- Runtime dependencies: `httpx`, `aiosqlite`, `aiofiles`, `openpyxl`, `lxml`, `rich`
- `ffmpeg-headless` added to `PATH` via `makeWrapperArgs`
- Entry point: `ttvd` CLI (from the repo's `main.py`)

### Registration
- Added to `pkgs/default.nix` with `addDoc` wrapper
- Added to `index.json`: `{ "attr": "ttvd", "ci": true, "docs": true }`
- Added to `pkgs/nixos/components/x86-rec-pkgs.nix` `home.packages` list

---

## Part 2: Flask UI (Vikunja task 44)

### Goal
A simple web interface to paste a TikTok URL, watch the video, and save it.

### Package location
`pkgs/python-packages/flasks/ttvd/`

Files:
- `default.nix` — Nix derivation (mirrors stampserver pattern)
- `setup.py` — minimal setuptools config
- `ttvdserver.py` — Flask application
- `index.html` — single-page UI

### Dependencies (Flask package)
- `flask`, `httpx`, `aiosqlite`, `aiofiles`, `openpyxl`, `lxml`, `rich`
- Same TikTokDownloader source (via flake input `ttvd-src`) as the CLI package
- `ffmpeg-headless` on PATH

### Routes

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/ttvd/` | Serve UI |
| POST | `/ttvd/api/fetch` | Download TikTok URL to server temp dir; returns token + metadata |
| GET | `/ttvd/api/stream/<token>` | Stream temp video to browser `<video>` player |
| GET | `/ttvd/api/client-download/<token>` | Send temp file as attachment (save to client) |
| POST | `/ttvd/api/save-to-server` | Move temp file to user-chosen server path |
| POST | `/ttvd/api/list-dirs` | Folder picker — identical to stampserver's `/api/list-dirs` |

### Download pipeline (Option A — direct Python import)
1. Flask receives URL via `POST /ttvd/api/fetch`
2. Constructs TikTokDownloader `Parameter` object pointing to `/tmp/ttvd/<token>/`
3. Calls `Extractor` to resolve the URL to video metadata
4. Calls `Downloader.run()` to download the mp4 to the temp dir
5. Returns token + filename to frontend

Fallback (Option C — server mode): if direct import proves too brittle, spawn TikTokDownloader in its HTTP server mode on a local port and proxy requests to it.

### Temp file lifecycle
- Temp dir: `/tmp/ttvd/<token>/` (one dir per fetch request)
- Cleaned up after `client-download` completes or after `save-to-server` moves the file
- Also cleaned on server restart (tmpfs)

### UI flow
1. User pastes TikTok URL into input field, clicks **Fetch**
2. Spinner while server downloads
3. `<video>` player appears with the downloaded video
4. Two buttons below:
   - **Download to this computer** — triggers `client-download`, browser saves file
   - **Save to server** — opens folder picker modal (same UX as stampserver), then calls `save-to-server`

### No authentication
The UI is open to anyone on the local network. No login page.

### No cookie management
Downloads public videos only at whatever quality is available without authentication.

---

## Part 3: ATS Wiring (Vikunja task 45)

### Port
Add `ttvd = 6060` to `pkgs/nixos/service-ports.nix`.

### NixOS module
Path: `pkgs/python-packages/flasks/ttvd/module.nix`

Options:
- `services.ttvd.enable` — boolean
- `services.ttvd.package` — defaults to `pkgs.ttvd-flask`

Config (when enabled):
- `systemd.tmpfiles.rules`: creates `/tmp/ttvd` with `andrew:dev` ownership
- `systemd.services.ttvd`: runs `ttvdserver --port 6060 --subdomain /ttvd`, `User=andrew`, `Group=dev`, `Restart=always`, `ReadWritePaths=["/tmp/ttvd"]`
- `machines.base.runWebServer = true`
- nginx proxy: `/ttvd/` → `127.0.0.1:6060/ttvd/`
- `machines.base.webServices`: registers `{ name = "TTVD"; path = "/ttvd/"; description = "TikTok video downloader"; }`

### pc-base.nix changes
- Import `../python-packages/flasks/ttvd/module.nix`
- `services.ttvd.enable = cfg.isATS`

---

## Package naming

| Nix attribute | Purpose |
|---------------|---------|
| `ttvd` | CLI package (recreational machines) |
| `ttvd-flask` | Flask web server (ATS only, via module) |

Both share the TikTokDownloader Python source via the same flake input.
