import argparse
import json
import os
from pathlib import Path

from flask import (
    Flask, Blueprint, request, render_template, redirect,
    url_for, session, Response, jsonify
)
from werkzeug.utils import secure_filename

from run_store import RunStore

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--subdomain", type=str, default="", help="URL prefix (e.g., '/budget')")
parser.add_argument("--config-file", type=str, default="~/configs/budget-tool.json",
                    help="Path to default budget config JSON file")
parser.add_argument("--state-dir", type=str, default="~/.local/state/budget-ui",
                    help="Directory for run log and state persistence")
args = parser.parse_args()

# Expand paths
config_path = Path(args.config_file).expanduser()
DATA_DIR = Path.home() / 'data' / 'budgets'
DATA_DIR.mkdir(parents=True, exist_ok=True)

state_dir = os.path.expanduser(args.state_dir)
upload_store = RunStore(os.path.join(state_dir, "upload"), "UPLOAD")
process_store = RunStore(os.path.join(state_dir, "process"), "PROCESS")

# Create blueprint with proper url_prefix
app = Flask(__name__)
bp = Blueprint('budget', __name__, url_prefix=args.subdomain)

def load_config():
    if 'config' in session:
        return session['config']
    if config_path.exists():
        with open(config_path) as f:
            config = json.load(f)
        session['config'] = config
        return config
    return None

@bp.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST' and 'config' in request.files:
        config_file = request.files['config']
        if config_file.filename:
            session['config'] = json.loads(config_file.read())
            session.pop('upload_output', None)
            session.pop('process_output', None)
            return redirect(url_for('budget.index'))

    config = load_config()
    if config is None:
        return render_template('upload_config.html',
                               has_default=config_path.exists(),
                               config_path=str(config_path),
                               subdomain=args.subdomain)

    sources = config.get('sources', [])
    statuses = {source['Account']: (DATA_DIR / f"{source['Account']}.csv").exists()
                for source in sources}

    return render_template('main.html',
                           sources=sources,
                           statuses=statuses,
                           subdomain=args.subdomain)

@bp.route('/upload/<account>', methods=['POST'])
def upload_csv(account):
    config = load_config()
    if not config:
        return "Config not loaded", 400

    valid_accounts = {s['Account'] for s in config.get('sources', [])}
    if account not in valid_accounts:
        return "Invalid account", 400

    if 'file' not in request.files:
        return "No file", 400
    file = request.files['file']
    if file.filename == '':
        return "No file selected", 400

    filename = secure_filename(f"{account}.csv")
    file.save(DATA_DIR / filename)
    return redirect(url_for('budget.index'))

@bp.route('/status')
def status():
    return jsonify({
        "upload": upload_store.read_state().get("status", "idle"),
        "process": process_store.read_state().get("status", "idle"),
    })

@bp.route('/trigger_upload', methods=['POST'])
def trigger_upload():
    upload_script = DATA_DIR / 'upload.sh'
    if not upload_script.exists():
        return jsonify({"error": "upload.sh not found at ~/data/budgets/upload.sh"}), 400
    if not upload_store.start(['bash', str(upload_script)]):
        return jsonify({"error": "Upload already in progress"}), 409
    return jsonify({"started": True}), 202

@bp.route('/stream/upload')
def stream_upload():
    return Response(
        upload_store.stream(),
        mimetype='text/event-stream',
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )

@bp.route('/trigger_process', methods=['POST'])
def trigger_process():
    if not process_store.start(
        ['budget_report', 'transactions-process'],
        env={**os.environ, 'PYTHONUNBUFFERED': '1'},
    ):
        return jsonify({"error": "Processing already in progress"}), 409
    return jsonify({"started": True}), 202

@bp.route('/stream/process')
def stream_process():
    return Response(
        process_store.stream(),
        mimetype='text/event-stream',
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )

# Serve static files correctly under the subpath
@app.route(f'{args.subdomain}/static/<path:filename>')
def custom_static(filename):
    return app.send_static_file(filename)

app.register_blueprint(bp)

def run():
    global args, app
    app.secret_key = os.urandom(24)
    app.run(host='0.0.0.0', port=args.port, debug=False, threaded=True)

if __name__ == '__main__':
    run()
