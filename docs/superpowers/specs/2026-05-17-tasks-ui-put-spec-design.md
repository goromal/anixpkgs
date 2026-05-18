# Tasks UI — "task-tools put-spec" Feature Design

**Date:** 2026-05-17  
**Project:** Tasks UI (Vikunja project #6, task #2)  
**Scope:** Add put-spec functionality to the existing tasks_ui Flask app

---

## Overview

Extend the existing `tasks_ui` Flask app with a second form section that exposes `task-tools put-spec` functionality: read a CSV of interval-based task specs and idempotently upload them to Google Tasks for a given date range, with a real-time calendar grid showing per-date results.

---

## Architecture & File Structure

No new files. Changes are confined to:

```
pkgs/python-packages/flasks/tasks_ui/
├── tasks_ui.py          ← new POST /spec-submit route + scheduling logic
├── templates/main.html  ← second form section + calendar grid + JS
└── tests/
    └── test_tasks_ui.py ← new tests for /spec-submit route
```

The put-spec scheduling logic (CSV reading, Sunday/quarter computation, idempotency check) is ported directly from the `task-tools` CLI into `tasks_ui.py`. No new modules, no subprocess calls.

---

## Backend

### New route: `POST /tasks/spec-submit`

**Request body (JSON):**
```json
{
  "start_date": "2026-07-06",
  "end_date":   "2026-10-05"
}
```

Both fields are required. The JS pre-fills them with CLI-matching defaults (see Frontend section).

**Response:** `Content-Type: text/event-stream`

One SSE event per day in the range:
```
data: {"date": "2026-07-06", "tasks": ["P0: Weekly Planning", "P0: Budget + Report"], "status": "ok"}
data: {"date": "2026-07-07", "tasks": [], "status": "skip"}
data: {"date": "2026-09-30", "tasks": [], "status": "error", "message": "API quota exceeded"}
```

Status values:
- `ok` — one or more tasks uploaded or already present (idempotent)
- `skip` — no tasks were due on this date
- `error` — at least one task failed; streaming continues for remaining dates

Terminal event: `data: {"done": true}`

**Processing logic (ported from CLI):**

1. Read `spec_csv` (default `~/configs/intervaled-tasks.csv`) once at request start
2. Parse pipe-delimited rows: `interval | title | description`
   - `d` = daily (every day)
   - `w` = weekly (every Sunday)
   - `m` = monthly (first Sunday of each calendar month)
   - `q` = quarterly (first Sunday of each quarter: Jan/Apr/Jul/Oct)
3. For each day from `start_date` to `end_date`:
   - Determine which task specs are due (based on interval rules above)
   - If none: emit `skip`
   - Else: call `getTasks(date, start_date=date)` to fetch existing tasks for that day
   - For each due spec not already present: call `putTask(title, description, date)`
   - Emit `ok` with list of task names actually uploaded this request (already-present tasks are not counted)
   - On any exception: emit `error` with message, continue

**`create_app` factory signature change:**

```python
def create_app(subdomain='', manager=None, spec_csv=None):
```

`spec_csv` defaults to `~/configs/intervaled-tasks.csv` when `None`. Tests inject a fixture path.

**Validation (HTTP 400 responses):**
- Non-JSON body
- Missing `start_date` or `end_date`
- Invalid date format (not `YYYY-MM-DD`)

---

## Frontend

A second section in `main.html`, below the existing "Upload Tasks" put form, separated by a horizontal rule.

### Form

**Heading:** "Upload Spec Tasks"

**Fields:**
- **Start date** — date picker, required; defaults to first Sunday of next quarter (computed in JS on page load to match CLI default)
- **End date** — date picker, required; defaults to first Sunday of the quarter after next (computed in JS on page load)
- **Upload Spec** button — disabled while streaming

### Calendar Grid

Appears below the spec form after submit starts. One cell per day in the date range, laid out in weekly rows with Mon–Sun columns (Sundays in the rightmost column).

**Cell states (populated reactively as SSE events arrive):**
- Outlined/unfilled — not yet reached in stream
- Green with task count badge — `ok` (e.g. "3" tasks uploaded)
- Red — `error`; hovering the cell shows the error message
- Light gray — `skip` (no tasks due)

**On stream complete:**
- All ok/skip → grid stays visible (no auto-reset; the user wants to see quarterly results)
- Any errors → grid stays, Upload Spec button re-enables for retry

### JS Date Helpers

Client-side functions matching CLI defaults:

```javascript
function firstSundayOfNextQuarter()       // start_date default
function firstSundayOfQuarterAfterNext()  // end_date default
```

Quarter months: Jan (1), Apr (4), Jul (7), Oct (10). "First Sunday of a quarter" = first Sunday on or after the 1st of the quarter's first month.

---

## Testing

New tests added to `tests/test_tasks_ui.py`. `create_app` is called with a fixture CSV string written to a temp file and a `MagicMock` manager.

| Test | Expected |
|------|----------|
| `GET /` | 200 (regression) |
| `POST /spec-submit` missing `start_date` | 400 |
| `POST /spec-submit` invalid date string | 400 |
| `POST /spec-submit` non-JSON body | 400 |
| Valid range → response type | `text/event-stream` |
| Sunday in range with weekly task | `ok` event, task name in `tasks` list |
| Non-Sunday with no daily tasks | `skip` event, empty `tasks` list |
| `getTasks` raises on a day | `error` event, stream continues |
| `putTask` raises on one task | `error` event, stream continues |

---

## Error Handling

- Invalid JSON / missing fields → HTTP 400 before streaming starts
- CSV file not found → HTTP 500 with message before streaming starts
- `TaskManager` not initialized → HTTP 500 with message
- Per-day API errors → `error` SSE event; remaining dates continue
- `end_date` before `start_date` → swap to `start_date` (match CLI behavior)

---

## Success Criteria

- Navigating to `/tasks/` shows both forms
- Start/end date pickers pre-fill with correct quarter defaults
- Submitting runs the spec upload; calendar grid populates in real-time
- Green cells show task count; red cells show error on hover
- Grid persists after completion (no auto-clear)
- All new tests pass alongside existing 7 tests
