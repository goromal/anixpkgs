# Tasks UI — "task-tools put" Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Flask web UI at `/tasks/` on the ATS machine that uploads tasks to Google Tasks for a date range, streaming per-date success/error feedback via SSE.

**Architecture:** New `tasks_ui` Python package following the `tester` module pattern. A `create_app(subdomain, manager)` factory keeps the app testable; `run()` handles arg parsing and `TaskManager` initialization at startup. The `/submit` route streams SSE events (one per date) as `TaskManager.putTask()` calls complete sequentially.

**Tech Stack:** Python 3.13, Flask, task-tools (Python library), Nix buildPythonPackage + NixOS module, vanilla JS with fetch + ReadableStream.

---

## File Map

**Create:**
- `pkgs/python-packages/flasks/tasks_ui/setup.py`
- `pkgs/python-packages/flasks/tasks_ui/default.nix`
- `pkgs/python-packages/flasks/tasks_ui/module.nix`
- `pkgs/python-packages/flasks/tasks_ui/tasks_ui.py`
- `pkgs/python-packages/flasks/tasks_ui/templates/main.html`
- `pkgs/python-packages/flasks/tasks_ui/tests/__init__.py` (empty)
- `pkgs/python-packages/flasks/tasks_ui/tests/test_tasks_ui.py`

**Modify:**
- `pkgs/nixos/service-ports.nix` — add `tasks_ui = 5959`
- `pkgs/default.nix` — register `tasks_ui` in two places (pySelf overlay + rec block)
- `index.json` — add `{"attr": "tasks_ui", "ci": true, "docs": true}` to python array
- `pkgs/nixos/pc-base.nix` — import module.nix + enable service conditionally on `isATS`

---

### Task 1: Package build files

**Goal:** Create `setup.py` and `default.nix` so Nix can build the `tasks_ui` package.

**Files:**
- Create: `pkgs/python-packages/flasks/tasks_ui/setup.py`
- Create: `pkgs/python-packages/flasks/tasks_ui/default.nix`

**Acceptance Criteria:**
- [ ] `setup.py` defines entry point `tasks_ui = tasks_ui:run`
- [ ] `default.nix` lists `flask` and `task-tools` in `propagatedBuildInputs`
- [ ] `default.nix` copies `templates/main.html` to the Nix output in `prePatch`

**Verify:** `cat pkgs/python-packages/flasks/tasks_ui/setup.py | grep tasks_ui` → shows entry point line

**Steps:**

- [ ] **Create `pkgs/python-packages/flasks/tasks_ui/setup.py`:**

```python
from setuptools import setup

setup(
    name='tasks_ui',
    version='0.0.1',
    py_modules=['tasks_ui'],
    entry_points={
        'console_scripts': ['tasks_ui = tasks_ui:run']
    },
)
```

- [ ] **Create `pkgs/python-packages/flasks/tasks_ui/default.nix`:**

```nix
{
  buildPythonPackage,
  setuptools,
  flask,
  task-tools,
  python,
}:
let
  pythonLibDir = "lib/python${python.passthru.pythonVersion}/site-packages";
in
buildPythonPackage rec {
  pname = "tasks_ui";
  version = "0.0.1";
  pyproject = true;
  build-system = [ setuptools ];
  src = ./.;
  prePatch = ''
    mkdir -p $out/${pythonLibDir}/templates
    cp ${./templates/main.html} $out/${pythonLibDir}/templates/main.html
  '';
  propagatedBuildInputs = [
    flask
    task-tools
  ];
  meta = {
    description = "Flask UI for task-tools on the ATS machine.";
    longDescription = "Provides a web interface for uploading tasks to Google Tasks using task-tools.";
    autoGenUsageCmd = "--help";
  };
}
```

- [ ] **Commit:**

```bash
git add pkgs/python-packages/flasks/tasks_ui/setup.py pkgs/python-packages/flasks/tasks_ui/default.nix
git commit -m "feat(tasks_ui): add package build files"
```

---

### Task 2: Flask backend with tests

**Goal:** Implement `tasks_ui.py` with a `create_app` factory and streaming `/submit` route, verified by unit tests.

**Files:**
- Create: `pkgs/python-packages/flasks/tasks_ui/tasks_ui.py`
- Create: `pkgs/python-packages/flasks/tasks_ui/tests/__init__.py`
- Create: `pkgs/python-packages/flasks/tasks_ui/tests/test_tasks_ui.py`

**Acceptance Criteria:**
- [ ] `GET /` returns 200
- [ ] `POST /submit` with missing or empty `name` returns 400
- [ ] `POST /submit` with non-JSON body returns 400
- [ ] `POST /submit` with valid args returns `text/event-stream` with one SSE event per date
- [ ] When `putTask` raises, that date emits `status: error` and streaming continues for remaining dates
- [ ] Multi-day range emits one event per day from start to end inclusive

**Verify:** `cd pkgs/python-packages/flasks/tasks_ui && python -m pytest tests/ -v` → all 6 tests pass

**Steps:**

- [ ] **Create `pkgs/python-packages/flasks/tasks_ui/tests/__init__.py`:** (empty file)

- [ ] **Write `pkgs/python-packages/flasks/tasks_ui/tests/test_tasks_ui.py` (failing tests first):**

```python
import json
import sys
import os
import pytest
from unittest.mock import MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))


def make_app(mock_manager=None):
    from tasks_ui import create_app
    return create_app(subdomain='', manager=mock_manager or MagicMock())


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
```

- [ ] **Run tests — verify they fail (no tasks_ui module yet):**

```bash
cd pkgs/python-packages/flasks/tasks_ui
pip install flask  # if not already available
python -m pytest tests/ -v 2>&1 | head -10
```
Expected: `ModuleNotFoundError: No module named 'tasks_ui'`

- [ ] **Create `pkgs/python-packages/flasks/tasks_ui/tasks_ui.py`:**

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


def create_app(subdomain='', manager=None):
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

    app.register_blueprint(bp)

    @app.route(f'{subdomain}/static/<path:filename>')
    def custom_static(filename):
        return app.send_static_file(filename)

    return app


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5959)
    parser.add_argument('--subdomain', type=str, default='/tasks')
    args = parser.parse_args()

    manager, err = _init_manager()
    if manager is None:
        print(f'Warning: TaskManager init failed: {err}', flush=True)

    app = create_app(subdomain=args.subdomain, manager=manager)
    app.secret_key = os.urandom(24)
    app.run(host='0.0.0.0', port=args.port, debug=False)


if __name__ == '__main__':
    run()
```

- [ ] **Run tests — verify they pass:**

```bash
cd pkgs/python-packages/flasks/tasks_ui
python -m pytest tests/ -v
```
Expected: `7 passed`

- [ ] **Commit:**

```bash
git add pkgs/python-packages/flasks/tasks_ui/tasks_ui.py \
        pkgs/python-packages/flasks/tasks_ui/tests/__init__.py \
        pkgs/python-packages/flasks/tasks_ui/tests/test_tasks_ui.py
git commit -m "feat(tasks_ui): add Flask backend with streaming submit and tests"
```

---

### Task 3: HTML template

**Goal:** Create `templates/main.html` — the single-page form with real-time SSE results list.

**Files:**
- Create: `pkgs/python-packages/flasks/tasks_ui/templates/main.html`

**Acceptance Criteria:**
- [ ] Form has task name input (required), start date (defaults to today), optional end date, notes toggle, upload button
- [ ] After submit, results list appears and populates row by row as SSE events arrive
- [ ] OK rows show green `✓`, error rows show red `✗ — <message>`
- [ ] Upload button is disabled while streaming
- [ ] On fully successful upload, form resets and results clear after 2 s
- [ ] On any error, results remain and form is re-enabled for retry

**Verify:** Start the app locally: `cd pkgs/python-packages/flasks/tasks_ui && python tasks_ui.py` → open `http://localhost:5959/tasks/` in browser, verify form renders with today's date pre-filled

**Steps:**

- [ ] **Create `pkgs/python-packages/flasks/tasks_ui/templates/main.html`:**

```html
<!DOCTYPE html>
<html>
<head>
  <title>Tasks</title>
  <meta charset="utf-8">
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; max-width: 600px; }
    h1 { margin-bottom: 24px; }
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

  <script>
    document.getElementById('date').valueAsDate = new Date();

    function toggleNotes() {
      const section = document.getElementById('notes-section');
      const toggle = document.getElementById('notes-toggle');
      const hidden = section.style.display === 'none' || section.style.display === '';
      section.style.display = hidden ? 'block' : 'none';
      toggle.textContent = hidden ? '− Notes' : '+ Notes';
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
        setTimeout(() => {
          resultsList.innerHTML = '';
          resultsList.style.display = 'none';
        }, 2000);
      }
    }
  </script>
</body>
</html>
```

- [ ] **Commit:**

```bash
git add pkgs/python-packages/flasks/tasks_ui/templates/main.html
git commit -m "feat(tasks_ui): add HTML template with SSE client"
```

---

### Task 4: NixOS module

**Goal:** Create `module.nix` to define the `tasks_ui` NixOS service with systemd + nginx proxy + web services registration.

**Files:**
- Create: `pkgs/python-packages/flasks/tasks_ui/module.nix`

**Acceptance Criteria:**
- [ ] Declares `options.services.tasks_ui.{enable, package, port, subdomain}`
- [ ] Registers `{name = "Tasks"; path = "/tasks/"; description = "Task management";}` in `machines.base.webServices`
- [ ] Defines `systemd.services.tasks_ui` running `tasks_ui --port <port> --subdomain <subdomain>`
- [ ] Adds nginx proxy for `<subdomain>/` → `127.0.0.1:<port><subdomain>/`
- [ ] `ReadWritePaths = [ "/" ]` (matches tester pattern for secrets access)

**Verify:** `nix-instantiate --parse pkgs/python-packages/flasks/tasks_ui/module.nix` → exits 0

**Steps:**

- [ ] **Create `pkgs/python-packages/flasks/tasks_ui/module.nix`:**

```nix
{
  pkgs,
  config,
  lib,
  ...
}:
with import ../../../nixos/dependencies.nix;
let
  globalCfg = config.machines.base;
  cfg = config.services.tasks_ui;
in
{
  options.services.tasks_ui = {
    enable = lib.mkEnableOption "enable tasks UI server";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The tasks_ui package to use";
      default = anixpkgs.tasks_ui;
    };
    port = lib.mkOption {
      type = lib.types.port;
      description = "Port to run the server on";
      default = service-ports.tasks_ui;
    };
    subdomain = lib.mkOption {
      type = lib.types.str;
      description = "Subdomain path for reverse proxy";
      default = "/tasks";
    };
  };

  config = lib.mkIf cfg.enable {
    machines.base.webServices = [
      {
        name = "Tasks";
        path = "/tasks/";
        description = "Task management";
      }
    ];

    systemd.services.tasks_ui = {
      enable = true;
      description = "Tasks UI Web Server";
      unitConfig = {
        StartLimitIntervalSec = 0;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/tasks_ui --port ${builtins.toString cfg.port} --subdomain ${cfg.subdomain}";
        ReadWritePaths = [ "/" ];
        WorkingDirectory = globalCfg.homeDir;
        Restart = "always";
        RestartSec = 5;
        User = "andrew";
        Group = "dev";
      };
      wantedBy = [ "multi-user.target" ];
    };

    machines.base.runWebServer = true;
    services.nginx.virtualHosts."${config.networking.hostName}.local" = {
      locations."${cfg.subdomain}/" = {
        proxyPass = "http://127.0.0.1:${builtins.toString cfg.port}${cfg.subdomain}/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };
}
```

- [ ] **Commit:**

```bash
git add pkgs/python-packages/flasks/tasks_ui/module.nix
git commit -m "feat(tasks_ui): add NixOS module"
```

---

### Task 5: Nix wiring

**Goal:** Wire `tasks_ui` into the Nix package set, service-ports, index, and pc-base.nix so the system knows about it.

**Files:**
- Modify: `pkgs/nixos/service-ports.nix`
- Modify: `pkgs/default.nix`
- Modify: `index.json`
- Modify: `pkgs/nixos/pc-base.nix`

**Acceptance Criteria:**
- [ ] `service-ports.nix` contains `tasks_ui = 5959;`
- [ ] `pkgs/default.nix` pySelf overlay contains `tasks_ui = addDoc (...)`
- [ ] `pkgs/default.nix` rec block contains `tasks_ui = final.python313.pkgs.tasks_ui;`
- [ ] `index.json` python array contains `{"attr": "tasks_ui", "ci": true, "docs": true}`
- [ ] `pc-base.nix` imports list includes `tasks_ui/module.nix`
- [ ] `pc-base.nix` config enables `services.tasks_ui` when `cfg.isATS`
- [ ] All new tasks_ui files are `git add`-ed before this step

**Verify:** `git status` → no untracked tasks_ui files remain

**Steps:**

- [ ] **Ensure all tasks_ui files are tracked first (critical — anix-upgrade uses `git ls-files`):**

```bash
git add pkgs/python-packages/flasks/tasks_ui/
git status
```
Expected: all tasks_ui files listed as staged (no untracked tasks_ui files).

- [ ] **Edit `pkgs/nixos/service-ports.nix` — add `tasks_ui = 5959;` before the closing brace:**

The file currently ends with:
```nix
  anix_upgrade_ui = 5858;
}
```

Change to:
```nix
  anix_upgrade_ui = 5858;
  tasks_ui = 5959;
}
```

- [ ] **Edit `pkgs/default.nix` — add `tasks_ui` to the pySelf overlay (around line 254, after `self-tester-app`):**

Find the block containing:
```nix
              self-tester-app = addDoc (pySelf.callPackage ./python-packages/flasks/tester { });
```

Add after it:
```nix
              tasks_ui = addDoc (pySelf.callPackage ./python-packages/flasks/tasks_ui { });
```

- [ ] **Edit `pkgs/default.nix` — add `tasks_ui` to the rec block (around line 357, after `self-tester-app`):**

Find:
```nix
  self-tester-app = final.python313.pkgs.self-tester-app;
```

Add after it:
```nix
  tasks_ui = final.python313.pkgs.tasks_ui;
```

- [ ] **Edit `index.json` — add `tasks_ui` to the python array:**

Open `index.json`, find the `python` array, and append:
```json
{"attr": "tasks_ui", "ci": true, "docs": true}
```
near the other Flask UI entries (e.g., after `anix_upgrade_ui`).

- [ ] **Edit `pkgs/nixos/pc-base.nix` — add module import (around line 224, after tester import):**

Find:
```nix
    ../python-packages/flasks/tester/module.nix
```

Add after it:
```nix
    ../python-packages/flasks/tasks_ui/module.nix
```

- [ ] **Edit `pkgs/nixos/pc-base.nix` — enable service (after the tester service block around line 510):**

Find:
```nix
    services.tester = {
      enable = cfg.isATS;
      dataDir = "${cfg.homeDir}/data/tester";
    };
```

Add after it:
```nix
    services.tasks_ui = {
      enable = cfg.isATS;
    };
```

- [ ] **Commit:**

```bash
git add pkgs/nixos/service-ports.nix pkgs/default.nix index.json pkgs/nixos/pc-base.nix
git commit -m "feat(tasks_ui): wire into Nix package set and pc-base"
```

---

### Task 6: Deploy and smoke-test

**Goal:** Deploy the tasks_ui to the ATS machine and verify the UI is accessible and functional.

**Files:** (no new files — deploy only)

**Acceptance Criteria:**
- [ ] `anix-upgrade --local` completes without build errors
- [ ] `http://<hostname>.local/tasks/` returns the Tasks form page
- [ ] The Tasks UI link appears on the ATS root landing page
- [ ] Submitting a task name + date via the form results in a `✓` row in the results list

**Verify:** `curl -s http://localhost:5959/tasks/ | grep 'Upload Tasks'` → shows the page title

**Steps:**

- [ ] **Confirm all files are committed and tracked:**

```bash
git status
```
Expected: clean working tree (nothing to commit).

- [ ] **Deploy:**

```bash
anix-upgrade --local -s /data/andrew/dev/claude/sources/anixpkgs
```
Expected: build succeeds, system switches. Watch for any Nix evaluation errors about `tasks_ui`.

- [ ] **Verify the service started:**

```bash
systemctl status tasks_ui
```
Expected: `Active: active (running)`

- [ ] **Smoke-test the UI endpoint:**

```bash
curl -s http://localhost:5959/tasks/ | grep 'Upload Tasks'
```
Expected: `<h1>Upload Tasks</h1>`

- [ ] **Verify the root landing page link:**

Open `http://<hostname>.local/` in a browser — confirm "Tasks" appears in the service list linking to `/tasks/`.

- [ ] **Manual golden-path test:** Submit a task for today's date with a recognizable name. Confirm the green `✓` row appears and the task shows up in Google Tasks.
