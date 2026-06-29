import argparse
import os
import signal

from flask import Blueprint, Flask, jsonify, render_template

DOLPHIN_MATCH = "/bin/dolphin-emu"


def _proc_cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return [a.decode("utf-8", "replace") for a in f.read().split(b"\0") if a]
    except OSError:
        return []


def _scan_dolphin():
    """Yield (pid, argv) for each running dolphin-emu process."""
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        argv = _proc_cmdline(pid)
        if any(DOLPHIN_MATCH in a for a in argv):
            yield pid, argv


def _game_from_argv(argv):
    for i, a in enumerate(argv):
        if a == "-e" and i + 1 < len(argv):
            return os.path.splitext(os.path.basename(argv[i + 1]))[0]
    return None


def find_dolphin():
    for pid, argv in _scan_dolphin():
        return pid, _game_from_argv(argv)
    return None, None


def create_app(subdomain=""):
    app = Flask(__name__)
    bp = Blueprint("sunset", __name__, url_prefix=subdomain)

    @bp.route("/")
    def index():
        return render_template("main.html", subdomain=subdomain)

    @bp.route("/status")
    def status():
        pid, game = find_dolphin()
        return jsonify({"running": pid is not None, "pid": pid, "game": game})

    @bp.route("/kill", methods=["POST"])
    def kill():
        killed = []
        for pid, _ in _scan_dolphin():
            try:
                os.kill(pid, signal.SIGKILL)
                killed.append(pid)
            except OSError:
                pass
        return jsonify({"killed": killed})

    app.register_blueprint(bp)
    return app


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5000)
    parser.add_argument("--subdomain", type=str, default="")
    args = parser.parse_args()
    app = create_app(args.subdomain)
    app.run(host="0.0.0.0", port=args.port, debug=False, threaded=True)


if __name__ == "__main__":
    main()
