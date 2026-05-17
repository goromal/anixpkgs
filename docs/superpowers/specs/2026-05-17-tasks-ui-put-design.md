# Tasks UI — "task-tools put" Feature Design

**Date:** 2026-05-17  
**Project:** Tasks UI (Vikunja project #6, task #1)  
**Scope:** Flask UI for the ATS machine that exposes `task-tools put` functionality

---

## Overview

A new Flask web UI called `tasks_ui` added to anixpkgs, accessible via the ATS root URL list. This first feature allows the user to upload tasks to Google Tasks for a date range, with real-time per-date feedback via server-sent events.

---

## Architecture & File Structure

```
anixpkgs/pkgs/python-packages/flasks/tasks_ui/
├── tasks_ui.py
├── default.nix
├── module.nix
├── setup.py
└── templates/
    └── main.html
```

Supporting changes:
- `pkgs/nixos/service-ports.nix` — add `tasks_ui = 5959`
- `pkgs/default.nix` — register `tasks_ui` package with `addDoc`
- `pkgs/nixos/pc-base.nix` — enable `services.tasks_ui` conditionally on `isATS`

The Flask app imports `task_tools.manage.TaskManager` directly (no subprocess). `task-tools` is added to `propagatedBuildInputs` in `default.nix`.

---

## Backend

**Entry point:** `tasks_ui.py`  
**Blueprint prefix:** `/tasks`

### Routes

| Method | Path | Description |
|--------|------|-------------|
| GET | `/tasks/` | Serves main page |
| POST | `/tasks/submit` | Streaming task upload |

### `POST /tasks/submit`

**Request body (JSON):**
```json
{
  "name": "Task name",
  "notes": "Optional notes",
  "date": "2026-05-17",
  "until": "2026-05-19"
}
```

- `name`: required
- `notes`: optional, defaults to `""`
- `date`: required, ISO date string
- `until`: optional; if absent or equal to `date`, only one date is processed

**Response:** `Content-Type: text/event-stream`

One SSE event per date:
```
data: {"date": "2026-05-17", "status": "ok"}
data: {"date": "2026-05-18", "status": "error", "message": "API quota exceeded"}
```

**Processing:** `TaskManager` is instantiated at app startup (reads credentials from `~/secrets` as task-tools does). The streaming route iterates dates from `date` to `until` inclusive, calling `TaskManager.putTask(name, notes, date)` for each, yielding one event per date as it completes.

---

## Frontend (main.html)

Single HTML page with vanilla JS (no framework).

### Form

- **Task name** — text input, required
- **Start date** — date picker, defaults to today
- **End date** — date picker, optional; if left blank, treated as same as start date
- **+ Notes** — toggle link; reveals a textarea when clicked, hidden by default
- **Upload** — submit button; disabled while streaming

### Results

Appears below the form after submit starts:

- Populated in real-time as SSE events arrive
- Each row: `2026-05-17 ✓` (green) or `2026-05-17 ✗ — <error message>` (red)
- On stream close:
  - All OK → form resets, results cleared
  - Any errors → results remain visible, form re-enabled for retry

### JS Behavior

1. On submit, POST JSON to `/tasks/submit` via `fetch` with streaming body read
2. Parse each newline-delimited SSE event as it arrives
3. Append a result row per event
4. On stream end: check for errors, reset or leave results accordingly
5. Upload button re-enabled after stream closes

---

## module.nix

Follows budget_ui pattern exactly:

- Declares `options.services.tasks_ui.{enable, package, pathPkgs}`
- `config = lib.mkIf cfg.enable { ... }`:
  - Adds `{name = "Tasks"; path = "/tasks/"; description = "Task management";}` to `machines.base.webServices`
  - Defines `systemd.services.tasks_ui` running `tasks_ui --subdomain /tasks --port 5959`
  - Adds nginx proxy for `/tasks/` → `127.0.0.1:5959`

---

## pc-base.nix Integration

```nix
services.tasks_ui.enable = isATS;
```

`task-tools` is a Python library dependency declared in `default.nix`'s `propagatedBuildInputs` — it does not need to be on the systemd service PATH.

---

## Error Handling

- Invalid JSON request body → HTTP 400
- Missing `name` field → HTTP 400
- `TaskManager` API errors on individual dates → caught per-date, emitted as `status: "error"` SSE events (upload continues for remaining dates)
- `TaskManager` init failure (bad credentials) → HTTP 500 with message

---

## Success Criteria

- Navigating to `/tasks/` on the ATS machine shows the form
- Submitting a task name + date range uploads one Google Task per day
- Results list populates in real-time, one row per date
- ✓ rows are green, ✗ rows are red with the error message
- Form resets after a fully successful upload
- The Tasks UI link appears on the ATS root landing page
