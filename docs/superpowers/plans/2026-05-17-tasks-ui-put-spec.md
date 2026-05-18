# Tasks UI — put-spec Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `put-spec` form section to the existing `tasks_ui` Flask app that reads `~/configs/intervaled-tasks.csv` and idempotently uploads interval-based tasks for a date range, with a real-time calendar grid visualization.

**Architecture:** Two files are modified — `tasks_ui.py` gains helper functions for schedule computation and a new `/spec-submit` SSE streaming route; `templates/main.html` gains a second form section with a calendar grid that populates reactively as events arrive. The `create_app` factory gains an optional `spec_csv` parameter so tests can inject a fixture CSV path without hitting the filesystem.

**Tech Stack:** Python 3, Flask, SSE streaming, vanilla JS, pytest with `tmp_path` fixture.

---

### Task 1: Backend `/spec-submit` route with scheduling logic and tests

**Goal:** Add schedule-computation helpers and the `/spec-submit` streaming route to `tasks_ui.py`, with 10 new tests covering validation, streaming, idempotency, and error handling.

**Files:**
- Modify: `pkgs/python-packages/flasks/tasks_ui/tasks_ui.py`
- Modify: `pkgs/python-packages/flasks/tasks_ui/tests/test_tasks_ui.py`

**Acceptance Criteria:**
- [ ] `create_app` accepts a `spec_csv` kwarg (default `~/configs/intervaled-tasks.csv`)
- [ ] `POST /spec-submit` without `start_date` or `end_date` returns 400
- [ ] `POST /spec-submit` with invalid date string returns 400
- [ ] `POST /spec-submit` with non-JSON body returns 400
- [ ] `POST /spec-submit` with valid range returns `text/event-stream`
- [ ] A Sunday in range emits `ok` event with weekly task names in `tasks` list
- [ ] A non-Sunday with no daily tasks emits `skip` event
- [ ] `getTasks` exception on a day emits `error` and stream continues
- [ ] `putTask` exception on a task emits `error` and stream continues to next day
- [ ] Task already present in Google Tasks is not re-uploaded (idempotent)
- [ ] All 17 tests pass (7 existing + 10 new)

**Verify:** `cd pkgs/python-packages/flasks/tasks_ui && python -m pytest tests/ -v` → 17 passed

**Steps:**

- [ ] **Step 1: Add 10 failing tests to `test_tasks_ui.py`**

Replace the full file with:

```python
import json
import sys
import os
import pytest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def make_app(mock_manager=None, spec_csv=None):
    from tasks_ui import create_app
    return create_app(subdomain='', manager=mock_manager or MagicMock(), spec_csv=spec_csv)


def test_index_returns_200():
    app = make_app()
    with app.test_client() as client:
        resp = client.get('/')
        assert resp.status_code == 200


def test_submit_missing_name_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'date': '2026-05-17'}),
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()


def test_submit_empty_name_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': '  ', 'date': '2026-05-17'}),
                           content_type='application/json')
        assert resp.status_code == 400


def test_submit_invalid_json_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/submit',
                           data='not json',
                           content_type='application/json')
        assert resp.status_code == 400


def test_submit_streams_ok_event():
    mock_mgr = MagicMock()
    mock_mgr.putTask.return_value = None
    app = make_app(mock_manager=mock_mgr)
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': 'Test Task', 'date': '2026-05-17'}),
                           content_type='application/json')
        assert resp.status_code == 200
        assert resp.mimetype == 'text/event-stream'
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 1
        assert payloads[0] == {'date': '2026-05-17', 'status': 'ok'}


def test_submit_streams_error_on_api_failure():
    mock_mgr = MagicMock()
    mock_mgr.putTask.side_effect = Exception('API quota exceeded')
    app = make_app(mock_manager=mock_mgr)
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': 'Test', 'date': '2026-05-17'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert payloads[0]['status'] == 'error'
        assert 'API quota exceeded' in payloads[0]['message']


def test_submit_multi_date_range():
    mock_mgr = MagicMock()
    app = make_app(mock_manager=mock_mgr)
    with app.test_client() as client:
        resp = client.post('/submit',
                           data=json.dumps({'name': 'Multi', 'date': '2026-05-17', 'until': '2026-05-19'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 3
        assert payloads[0]['date'] == '2026-05-17'
        assert payloads[1]['date'] == '2026-05-18'
        assert payloads[2]['date'] == '2026-05-19'


# --- /spec-submit tests ---
# Note: 2026-07-05 is a Sunday (verified: Jan 1, 2026 is Thursday; (3+185)%7=6=Sunday)
# 2026-07-06 is Monday. 2026-07-12 is the next Sunday.
# 2026-07-05 is also the first Sunday of Q3 2026 and first Sunday of July 2026.

def test_spec_submit_missing_start_date_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'end_date': '2026-10-05'}),
                           content_type='application/json')
        assert resp.status_code == 400
        assert 'error' in resp.get_json()


def test_spec_submit_missing_end_date_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-06'}),
                           content_type='application/json')
        assert resp.status_code == 400


def test_spec_submit_invalid_date_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': 'not-a-date', 'end_date': '2026-10-05'}),
                           content_type='application/json')
        assert resp.status_code == 400


def test_spec_submit_non_json_returns_400():
    app = make_app()
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data='not json',
                           content_type='application/json')
        assert resp.status_code == 400


def test_spec_submit_returns_event_stream(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    mock_mgr.putTask.return_value = None
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-06'}),
                           content_type='application/json')
        assert resp.status_code == 200
        assert resp.mimetype == 'text/event-stream'


def test_spec_submit_sunday_emits_ok_with_weekly_task(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    mock_mgr.putTask.return_value = None
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 1
        assert payloads[0]['status'] == 'ok'
        assert 'P0: Weekly Task' in payloads[0]['tasks']


def test_spec_submit_non_sunday_emits_skip(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-06', 'end_date': '2026-07-06'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert len(payloads) == 1
        assert payloads[0]['status'] == 'skip'


def test_spec_submit_get_tasks_error_emits_error(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.side_effect = Exception('API error')
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert payloads[0]['status'] == 'error'
        assert 'API error' in payloads[0]['message']


def test_spec_submit_put_task_error_continues_stream(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    mock_mgr.getTasks.return_value = []
    # First Sunday (2026-07-05) fails, second Sunday (2026-07-12) succeeds
    mock_mgr.putTask.side_effect = [Exception('quota'), None]
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-12'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        non_skip = [p for p in payloads if p['status'] != 'skip']
        assert len(non_skip) == 2
        assert non_skip[0]['status'] == 'error'
        assert non_skip[1]['status'] == 'ok'


def test_spec_submit_idempotent_skips_existing(tmp_path):
    csv = tmp_path / 'tasks.csv'
    csv.write_text('w|P0: Weekly Task|\n')
    mock_mgr = MagicMock()
    existing = MagicMock()
    existing.name = 'P0: Weekly Task'
    mock_mgr.getTasks.return_value = [existing]
    app = make_app(mock_manager=mock_mgr, spec_csv=str(csv))
    with app.test_client() as client:
        resp = client.post('/spec-submit',
                           data=json.dumps({'start_date': '2026-07-05', 'end_date': '2026-07-05'}),
                           content_type='application/json')
        body = resp.get_data(as_text=True)
        payloads = [json.loads(line[6:]) for line in body.splitlines()
                    if line.startswith('data: ') and '"done"' not in line]
        assert payloads[0]['status'] == 'ok'
        assert payloads[0]['tasks'] == []
        mock_mgr.putTask.assert_not_called()
```

- [ ] **Step 2: Run tests to confirm 10 failures**

```bash
cd pkgs/python-packages/flasks/tasks_ui && python -m pytest tests/ -v 2>&1 | tail -20
```

Expected: 7 passing, 10 failing (ERRORS on spec-submit tests since route doesn't exist yet).

- [ ] **Step 3: Implement the updated `tasks_ui.py`**

Replace the full file with:

```python
import argparse
import datetime
import json
import os

from flask import Flask, Blueprint, request, render_template, Response, stream_with_context


def _init_manager():
    from task_tools.manage import TaskManager
    try:
        return TaskManager(), None
    except Exception as e:
        return None, str(e)


def _all_sundays(start, end):
    result = []
    current = start
    while current.weekday() != 6:
        current += datetime.timedelta(days=1)
    while current <= end:
        result.append(current)
        current += datetime.timedelta(days=7)
    return result


def _first_sundays_of_month(start, end):
    result = []
    month = start.month
    year = start.year
    while datetime.datetime(year, month, 1) <= end:
        first = datetime.datetime(year, month, 1)
        while first.weekday() != 6:
            first += datetime.timedelta(days=1)
        if start <= first <= end:
            result.append(first)
        if month == 12:
            month = 1
            year += 1
        else:
            month += 1
    return result


def _first_sundays_of_quarter(start, end):
    quarter_months = {1, 4, 7, 10}
    return [d for d in _first_sundays_of_month(start, end) if d.month in quarter_months]


def _read_spec_csv(path):
    daily, weekly, monthly, quarterly = [], [], [], []
    with open(path, 'r') as f:
        for line in f:
            parts = line.split('|')
            if len(parts) < 2:
                continue
            rtype = parts[0].strip().lower()
            title = parts[1].strip()
            desc = parts[2].strip() if len(parts) > 2 else ''
            if rtype == 'd':
                daily.append((title, desc))
            elif rtype == 'w':
                weekly.append((title, desc))
            elif rtype == 'm':
                monthly.append((title, desc))
            elif rtype == 'q':
                quarterly.append((title, desc))
    return daily, weekly, monthly, quarterly


def create_app(subdomain='', manager=None, spec_csv=None):
    _spec_csv = os.path.expanduser(spec_csv or '~/configs/intervaled-tasks.csv')
    app = Flask(__name__)
    bp = Blueprint('tasks', __name__, url_prefix=subdomain)

    @bp.route('/', methods=['GET'])
    def index():
        return render_template('main.html')

    @bp.route('/submit', methods=['POST'])
    def submit():
        if manager is None:
            return {'error': 'TaskManager not initialized — check secrets'}, 500

        data = request.get_json(silent=True)
        if data is None:
            return {'error': 'Invalid JSON'}, 400

        name = (data.get('name') or '').strip()
        if not name:
            return {'error': 'name is required'}, 400

        notes = data.get('notes') or ''
        date_str = data.get('date')
        until_str = data.get('until')

        try:
            start = datetime.datetime.strptime(date_str, '%Y-%m-%d')
        except (TypeError, ValueError):
            return {'error': 'invalid date'}, 400

        if until_str:
            try:
                end = datetime.datetime.strptime(until_str, '%Y-%m-%d')
            except ValueError:
                return {'error': 'invalid until'}, 400
            if end < start:
                end = start
        else:
            end = start

        def generate():
            current = start
            while current <= end:
                label = current.strftime('%Y-%m-%d')
                try:
                    manager.putTask(name, notes, current)
                    event = json.dumps({'date': label, 'status': 'ok'})
                except Exception as exc:
                    event = json.dumps({'date': label, 'status': 'error', 'message': str(exc)})
                yield f'data: {event}\n\n'
                current += datetime.timedelta(days=1)
            yield 'data: {"done": true}\n\n'

        return Response(stream_with_context(generate()), mimetype='text/event-stream')

    @bp.route('/spec-submit', methods=['POST'])
    def spec_submit():
        if manager is None:
            return {'error': 'TaskManager not initialized — check secrets'}, 500

        data = request.get_json(silent=True)
        if data is None:
            return {'error': 'Invalid JSON'}, 400

        start_str = data.get('start_date')
        end_str = data.get('end_date')

        if not start_str or not end_str:
            return {'error': 'start_date and end_date are required'}, 400

        try:
            start = datetime.datetime.strptime(start_str, '%Y-%m-%d')
            end = datetime.datetime.strptime(end_str, '%Y-%m-%d')
        except ValueError:
            return {'error': 'invalid date format'}, 400

        if end < start:
            end = start

        try:
            daily, weekly, monthly, quarterly = _read_spec_csv(_spec_csv)
        except FileNotFoundError:
            return {'error': f'CSV not found: {_spec_csv}'}, 500

        sundays = set(_all_sundays(start, end))
        month_sundays = set(_first_sundays_of_month(start, end))
        quarter_sundays = set(_first_sundays_of_quarter(start, end))

        def generate():
            current = start
            while current <= end:
                label = current.strftime('%Y-%m-%d')
                due = list(daily)
                if current in sundays:
                    due += weekly
                if current in month_sundays:
                    due += monthly
                if current in quarter_sundays:
                    due += quarterly

                if not due:
                    yield f'data: {json.dumps({"date": label, "tasks": [], "status": "skip"})}\n\n'
                    current += datetime.timedelta(days=1)
                    continue

                try:
                    existing_names = {t.name for t in manager.getTasks(date=current, start_date=current)}
                except Exception as exc:
                    yield f'data: {json.dumps({"date": label, "tasks": [], "status": "error", "message": str(exc)})}\n\n'
                    current += datetime.timedelta(days=1)
                    continue

                uploaded = []
                error_msg = None
                for title, desc in due:
                    if title in existing_names:
                        continue
                    try:
                        manager.putTask(title, desc, current)
                        uploaded.append(title)
                    except Exception as exc:
                        error_msg = str(exc)

                if error_msg:
                    event = json.dumps({'date': label, 'tasks': uploaded, 'status': 'error', 'message': error_msg})
                else:
                    event = json.dumps({'date': label, 'tasks': uploaded, 'status': 'ok'})
                yield f'data: {event}\n\n'
                current += datetime.timedelta(days=1)
            yield 'data: {"done": true}\n\n'

        return Response(stream_with_context(generate()), mimetype='text/event-stream')

    app.register_blueprint(bp)

    @app.route(f'{subdomain}/static/<path:filename>')
    def custom_static(filename):
        return app.send_static_file(filename)

    return app


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5959)
    parser.add_argument('--subdomain', type=str, default='/tasks')
    parser.add_argument('--spec-csv', type=str, default='~/configs/intervaled-tasks.csv')
    args = parser.parse_args()

    manager, err = _init_manager()
    if manager is None:
        print(f'Warning: TaskManager init failed: {err}', flush=True)

    app = create_app(subdomain=args.subdomain, manager=manager, spec_csv=args.spec_csv)
    app.secret_key = os.urandom(24)
    app.run(host='0.0.0.0', port=args.port, debug=False)


if __name__ == '__main__':
    run()
```

- [ ] **Step 4: Run tests to confirm all 17 pass**

```bash
cd pkgs/python-packages/flasks/tasks_ui && python -m pytest tests/ -v
```

Expected output ends with: `17 passed`

- [ ] **Step 5: Commit**

```bash
git add pkgs/python-packages/flasks/tasks_ui/tasks_ui.py \
        pkgs/python-packages/flasks/tasks_ui/tests/test_tasks_ui.py
git commit -m "feat(tasks_ui): add /spec-submit route with scheduling logic and tests"
```

---

### Task 2: Frontend spec form and calendar grid

**Goal:** Add the "Upload Spec Tasks" section to `main.html` with start/end date pickers (defaulting to CLI-matching quarter boundaries), a spec upload button, and a reactive calendar grid that colors cells green/gray/red as SSE events arrive.

**Files:**
- Modify: `pkgs/python-packages/flasks/tasks_ui/templates/main.html`

**Acceptance Criteria:**
- [ ] Page shows "Upload Spec Tasks" heading below a horizontal rule
- [ ] Start date defaults to first Sunday of next quarter; end date to first Sunday of quarter after next
- [ ] Submitting calls `POST spec-submit` and the calendar grid appears
- [ ] Green cells (class `ok`) show a task-count badge; red cells (class `error`) show `!` and a hover tooltip; gray cells (class `skip`) show just the day number
- [ ] Calendar lays out Mon–Sun columns with month labels at the start of each new-month row
- [ ] Out-of-range padding cells are invisible
- [ ] Calendar persists after stream completes (no auto-clear)
- [ ] Upload Spec button re-enables after stream completes

**Verify:** After `git add` + `anix-upgrade --local -s /data/andrew/dev/claude/sources/anixpkgs`, `curl -s http://localhost:5959/tasks/ | grep 'Upload Spec Tasks'` → outputs the h2 tag line

**Steps:**

- [ ] **Step 1: Replace `templates/main.html` with the updated version**

```html
<!DOCTYPE html>
<html>
<head>
  <title>Tasks</title>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; max-width: 620px; }
    h1 { margin-bottom: 24px; }
    h2 { font-size: 20px; margin-bottom: 20px; }
    label { display: block; margin: 12px 0 4px; font-weight: bold; }
    input[type="text"], input[type="date"], textarea {
      width: 100%; padding: 8px; box-sizing: border-box;
      border: 1px solid #ccc; border-radius: 4px; font-size: 14px;
    }
    textarea { height: 80px; resize: vertical; }
    #notes-section { margin-top: 4px; display: none; }
    #notes-toggle {
      cursor: pointer; color: #0066cc; font-size: 13px;
      margin-top: 8px; display: inline-block; user-select: none;
    }
    button[type="submit"] {
      margin-top: 20px; padding: 10px 24px; background: #0066cc;
      color: white; border: none; border-radius: 4px; font-size: 16px; cursor: pointer;
    }
    button[type="submit"]:disabled { background: #aaa; cursor: not-allowed; }
    #results { list-style: none; padding: 0; margin-top: 20px; display: none; }
    #results li { padding: 4px 0; font-family: monospace; font-size: 14px; }
    #results li.ok { color: green; }
    #results li.error { color: red; }

    .section-divider { margin: 36px 0; border: none; border-top: 1px solid #ccc; }
    #spec-error { color: red; margin-top: 8px; display: none; }
    #spec-calendar { margin-top: 24px; display: none; }
    .cal-grid { display: grid; grid-template-columns: repeat(7, 1fr); gap: 3px; }
    .cal-header {
      text-align: center; font-size: 11px; font-weight: bold; color: #666; padding: 3px 0;
    }
    .cal-month-label {
      grid-column: 1 / span 7; font-size: 12px; font-weight: bold;
      color: #333; padding: 8px 2px 2px;
    }
    .cal-cell {
      height: 44px; border: 1px dashed #ddd; border-radius: 3px;
      display: flex; flex-direction: column;
      align-items: center; justify-content: center;
      font-size: 11px; position: relative; background: #fafafa;
    }
    .cal-cell.out-of-range { background: transparent; border: none; visibility: hidden; }
    .cal-cell.skip { background: #f0f0f0; border: 1px solid #e0e0e0; color: #aaa; }
    .cal-cell.ok { background: #e8f5e9; border: 1px solid #81c784; color: #2e7d32; }
    .cal-cell.error { background: #ffebee; border: 1px solid #e57373; color: #c62828; cursor: help; }
    .cal-cell .day-num { font-weight: bold; font-size: 12px; }
    .cal-cell .badge {
      font-size: 9px; background: #43a047; color: white;
      border-radius: 8px; padding: 0 5px; margin-top: 2px; line-height: 14px;
    }
    .cal-cell.error .badge { background: #e53935; }
  </style>
</head>
<body>
  <h1>Upload Tasks</h1>
  <form id="task-form" onsubmit="submitTask(event)">
    <label for="name">Task name</label>
    <input type="text" id="name" name="name" required placeholder="e.g. P1: Weekly review">

    <label for="date">Start date</label>
    <input type="date" id="date" name="date" required>

    <label for="until">End date <span style="font-weight:normal;font-size:12px">(optional — defaults to start date)</span></label>
    <input type="date" id="until" name="until">

    <a id="notes-toggle" onclick="toggleNotes()">+ Notes</a>
    <div id="notes-section">
      <label for="notes">Notes</label>
      <textarea id="notes" name="notes"></textarea>
    </div>

    <button type="submit" id="submit-btn">Upload</button>
  </form>

  <ul id="results"></ul>

  <hr class="section-divider">

  <h2>Upload Spec Tasks</h2>
  <form id="spec-form" onsubmit="submitSpec(event)">
    <label for="spec-start">Start date</label>
    <input type="date" id="spec-start" name="spec-start" required>

    <label for="spec-end">End date</label>
    <input type="date" id="spec-end" name="spec-end" required>

    <button type="submit" id="spec-submit-btn">Upload Spec</button>
  </form>
  <p id="spec-error"></p>

  <div id="spec-calendar"></div>

  <script>
    // --- Put Task form ---
    document.getElementById('date').valueAsDate = new Date();

    function toggleNotes() {
      const section = document.getElementById('notes-section');
      const toggle = document.getElementById('notes-toggle');
      const hidden = section.style.display === 'none' || section.style.display === '';
      section.style.display = hidden ? 'block' : 'none';
      toggle.textContent = hidden ? '\u2212 Notes' : '+ Notes';
    }

    async function submitTask(event) {
      event.preventDefault();
      const name = document.getElementById('name').value.trim();
      const date = document.getElementById('date').value;
      const until = document.getElementById('until').value || null;
      const notes = document.getElementById('notes').value;
      const btn = document.getElementById('submit-btn');
      const resultsList = document.getElementById('results');

      btn.disabled = true;
      resultsList.innerHTML = '';
      resultsList.style.display = 'block';
      let hasError = false;

      const resp = await fetch('submit', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({name, notes, date, until})
      });

      if (!resp.ok) {
        const err = await resp.json().catch(() => ({error: 'Unknown error'}));
        const li = document.createElement('li');
        li.textContent = 'Error: ' + err.error;
        li.className = 'error';
        resultsList.appendChild(li);
        btn.disabled = false;
        return;
      }

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buf = '';
      while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        buf += decoder.decode(value, {stream: true});
        const lines = buf.split('\n');
        buf = lines.pop();
        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const data = JSON.parse(line.slice(6));
          if (data.done) continue;
          const li = document.createElement('li');
          if (data.status === 'ok') {
            li.textContent = data.date + ' \u2713';
            li.className = 'ok';
          } else {
            li.textContent = data.date + ' \u2717 \u2014 ' + data.message;
            li.className = 'error';
            hasError = true;
          }
          resultsList.appendChild(li);
        }
      }

      btn.disabled = false;
      if (!hasError) {
        document.getElementById('task-form').reset();
        document.getElementById('date').valueAsDate = new Date();
        document.getElementById('notes-section').style.display = 'none';
        document.getElementById('notes-toggle').textContent = '+ Notes';
        setTimeout(() => { resultsList.innerHTML = ''; resultsList.style.display = 'none'; }, 2000);
      }
    }

    // --- Spec date helpers (match task-tools CLI quarter logic) ---

    function toISODate(d) {
      return d.toISOString().slice(0, 10);
    }

    function firstSundayOnOrAfter(d) {
      const result = new Date(d);
      const day = result.getDay();
      if (day !== 0) result.setDate(result.getDate() + (7 - day));
      return result;
    }

    function firstSundayOfNthNextQuarter(n) {
      const today = new Date();
      const currentQuarter = Math.floor(today.getMonth() / 3);
      const targetQuarter = currentQuarter + n;
      const targetYear = today.getFullYear() + Math.floor(targetQuarter / 4);
      const targetMonth = (targetQuarter % 4) * 3;
      return firstSundayOnOrAfter(new Date(targetYear, targetMonth, 1));
    }

    document.getElementById('spec-start').value = toISODate(firstSundayOfNthNextQuarter(1));
    document.getElementById('spec-end').value = toISODate(firstSundayOfNthNextQuarter(2));

    // --- Calendar grid ---

    let calCells = {};

    function buildCalendar(startStr, endStr) {
      const cal = document.getElementById('spec-calendar');
      cal.innerHTML = '';
      cal.style.display = 'block';
      calCells = {};

      const start = new Date(startStr + 'T00:00:00');
      const end = new Date(endStr + 'T00:00:00');

      const grid = document.createElement('div');
      grid.className = 'cal-grid';

      ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].forEach(d => {
        const h = document.createElement('div');
        h.className = 'cal-header';
        h.textContent = d;
        grid.appendChild(h);
      });

      // Pad to Monday before start, Sunday after end
      const startDay = start.getDay();
      const daysBackToMon = startDay === 0 ? 6 : startDay - 1;
      const gridStart = new Date(start);
      gridStart.setDate(start.getDate() - daysBackToMon);

      const endDay = end.getDay();
      const daysForwardToSun = endDay === 0 ? 0 : 7 - endDay;
      const gridEnd = new Date(end);
      gridEnd.setDate(end.getDate() + daysForwardToSun);

      let lastMonthLabel = null;
      let current = new Date(gridStart);

      while (current <= gridEnd) {
        if (current.getDay() === 1) {
          const monthStr = current.toLocaleString('default', {month: 'long', year: 'numeric'});
          if (monthStr !== lastMonthLabel) {
            const label = document.createElement('div');
            label.className = 'cal-month-label';
            label.textContent = monthStr;
            grid.appendChild(label);
            lastMonthLabel = monthStr;
          }
        }

        const dateStr = toISODate(current);
        const inRange = current >= start && current <= end;
        const cell = document.createElement('div');

        if (inRange) {
          cell.className = 'cal-cell';
          const dayNum = document.createElement('span');
          dayNum.className = 'day-num';
          dayNum.textContent = current.getDate();
          cell.appendChild(dayNum);
          calCells[dateStr] = cell;
        } else {
          cell.className = 'cal-cell out-of-range';
        }

        grid.appendChild(cell);
        current.setDate(current.getDate() + 1);
      }

      cal.appendChild(grid);
    }

    function updateCalendarCell(dateStr, status, tasks, message) {
      const cell = calCells[dateStr];
      if (!cell) return;
      cell.className = 'cal-cell ' + status;
      cell.innerHTML = '';
      const dayNum = document.createElement('span');
      dayNum.className = 'day-num';
      dayNum.textContent = parseInt(dateStr.slice(8), 10);
      cell.appendChild(dayNum);
      if (status === 'ok' && tasks && tasks.length > 0) {
        const badge = document.createElement('span');
        badge.className = 'badge';
        badge.textContent = tasks.length;
        cell.appendChild(badge);
      } else if (status === 'error') {
        if (message) cell.title = message;
        const badge = document.createElement('span');
        badge.className = 'badge';
        badge.textContent = '!';
        cell.appendChild(badge);
      }
    }

    // --- Spec form submission ---

    async function submitSpec(event) {
      event.preventDefault();
      const startDate = document.getElementById('spec-start').value;
      const endDate = document.getElementById('spec-end').value;
      const btn = document.getElementById('spec-submit-btn');
      const errEl = document.getElementById('spec-error');

      btn.disabled = true;
      errEl.style.display = 'none';
      buildCalendar(startDate, endDate);

      const resp = await fetch('spec-submit', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({start_date: startDate, end_date: endDate})
      });

      if (!resp.ok) {
        const err = await resp.json().catch(() => ({error: 'Unknown error'}));
        errEl.textContent = 'Error: ' + err.error;
        errEl.style.display = 'block';
        btn.disabled = false;
        return;
      }

      const reader = resp.body.getReader();
      const decoder = new TextDecoder();
      let buf = '';
      while (true) {
        const {done, value} = await reader.read();
        if (done) break;
        buf += decoder.decode(value, {stream: true});
        const lines = buf.split('\n');
        buf = lines.pop();
        for (const line of lines) {
          if (!line.startsWith('data: ')) continue;
          const data = JSON.parse(line.slice(6));
          if (data.done) continue;
          updateCalendarCell(data.date, data.status, data.tasks, data.message);
        }
      }

      btn.disabled = false;
    }
  </script>
</body>
</html>
```

- [ ] **Step 2: Stage all modified files and deploy**

```bash
git add pkgs/python-packages/flasks/tasks_ui/templates/main.html
anix-upgrade --local -s /data/andrew/dev/claude/sources/anixpkgs
```

Expected: build completes without errors, `systemctl status tasks_ui` shows active.

- [ ] **Step 3: Smoke-test the deployed page**

```bash
rtk proxy curl -s http://localhost:5959/tasks/ | grep 'Upload Spec Tasks'
```

Expected output contains: `<h2>Upload Spec Tasks</h2>`

Also verify in browser:
- Navigate to `http://ats.local/tasks/`
- Confirm both forms are visible
- Confirm spec start/end date pickers are pre-filled with correct quarter dates
- Submit spec form and watch calendar populate cell-by-cell

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(tasks_ui): add put-spec form and calendar grid to main.html"
```
