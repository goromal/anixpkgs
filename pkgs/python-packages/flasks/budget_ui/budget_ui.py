import argparse
import json
import os
import subprocess
from pathlib import Path

from flask import (
    Flask, Blueprint, request, render_template, redirect,
    url_for, session, Response, stream_with_context
)
from werkzeug.utils import secure_filename

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--subdomain", type=str, default="", help="URL prefix (e.g., '/budget')")
parser.add_argument("--config-file", type=str, default="~/configs/budget-tool.json",
                    help="Path to default budget config JSON file")
args = parser.parse_args()

# Expand paths
config_path = Path(args.config_file).expanduser()
DATA_DIR = Path.home() / 'data' / 'budgets'
DATA_DIR.mkdir(parents=True, exist_ok=True)

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
                               config_path=str(config_path))

    sources = config.get('sources', [])
    statuses = {source['Account']: (DATA_DIR / f"{source['Account']}.csv").exists()
                for source in sources}

    return render_template('main.html',
                           sources=sources,
                           statuses=statuses)

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

def stream_command(command):
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        universal_newlines=True
    )
    for line in process.stdout:
        yield line.rstrip('\n')
    process.wait()
    if process.returncode != 0:
        yield f"[Command failed with exit code {process.returncode}]"

@bp.route('/trigger_upload')
def trigger_upload():
    def generate():
        upload_script = DATA_DIR / 'upload.sh'
        if not upload_script.exists():
            yield "data: Error: upload.sh not found at ~/data/budgets/upload.sh\n\n"
            return
        for line in stream_command(['bash', str(upload_script)]):
            yield f"data: {line}\n\n"
        yield "data: [Upload script finished]\n\n"
    return Response(stream_with_context(generate()), mimetype='text/event-stream')

@bp.route('/trigger_process')
def trigger_process():
    def generate():
        for line in stream_command(['budget_report', 'transactions-process']):
            yield f"data: {line}\n\n"
        yield "data: [Processing complete]\n\n"
    return Response(stream_with_context(generate()), mimetype='text/event-stream')

# Serve static files correctly under the subpath
@app.route(f'{args.subdomain}/static/<path:filename>')
def custom_static(filename):
    return app.send_static_file(filename)

app.register_blueprint(bp)

def run():
    global args, app
    app.secret_key = os.urandom(24)
    app.run(host='0.0.0.0', port=args.port, debug=False)

if __name__ == '__main__':
    run()
