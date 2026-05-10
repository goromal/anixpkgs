import argparse
import subprocess
import threading
import time
import os

from flask import Flask, Blueprint, render_template, Response, stream_with_context, jsonify

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=5000)
parser.add_argument("--subdomain", type=str, default="")
parser.add_argument("--anix-upgrade-bin", type=str, default="anix-upgrade",
                    help="Path to the anix-upgrade binary")
args = parser.parse_args()

app = Flask(__name__)
bp = Blueprint("anix_upgrade_ui", __name__, url_prefix=args.subdomain)

_lock = threading.Lock()
_running = False
_last_status = "idle"  # idle | running | success | failed


def current_version():
    try:
        with open(os.path.expanduser("~/.anix-version")) as f:
            return f.read().strip()
    except OSError:
        return "unknown"


def current_meta():
    try:
        with open(os.path.expanduser("~/.anix-meta")) as f:
            return f.read().strip()
    except OSError:
        return ""


@bp.route("/")
def index():
    return render_template(
        "main.html",
        subdomain=args.subdomain,
        version=current_version(),
        meta=current_meta(),
        status=_last_status,
    )


@bp.route("/status")
def status():
    global _running, _last_status
    return jsonify({
        "running": _running,
        "status": _last_status,
        "version": current_version(),
        "meta": current_meta(),
    })


@bp.route("/run", methods=["POST"])
def run():
    from flask import request

    global _running, _last_status

    with _lock:
        if _running:
            return jsonify({"error": "Upgrade already in progress"}), 409
        _running = True
        _last_status = "running"

    version = request.form.get("version", "").strip()
    commit = request.form.get("commit", "").strip()
    branch = request.form.get("branch", "").strip()
    source = request.form.get("source", "").strip()
    local = request.form.get("local") == "1"
    boot = request.form.get("boot") == "1"

    cmd = [args.anix_upgrade_bin]
    if version:
        cmd += ["-v", version]
    elif commit:
        cmd += ["-c", commit]
    elif branch:
        cmd += ["-b", branch]
    elif source:
        cmd += ["-s", source]
    if local:
        cmd += ["--local"]
    if boot:
        cmd += ["--boot"]

    def generate():
        global _running, _last_status
        try:
            proc = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            for line in proc.stdout:
                yield f"data: {line.rstrip()}\n\n"
            proc.wait()
            if proc.returncode == 0:
                _last_status = "success"
                yield "data: [UPGRADE SUCCESSFUL]\n\n"
            else:
                _last_status = "failed"
                yield f"data: [UPGRADE FAILED (exit {proc.returncode})]\n\n"
        except Exception as e:
            _last_status = "failed"
            yield f"data: [ERROR: {e}]\n\n"
        finally:
            _running = False
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype="text/event-stream")


app.register_blueprint(bp)


def run():
    app.run(host="0.0.0.0", port=args.port, debug=False)


if __name__ == "__main__":
    run()
