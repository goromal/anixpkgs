"""Video Downloader Flask server — download videos from YouTube, TikTok, and more."""
import argparse
import json
import os
import shutil
import subprocess
import uuid
from pathlib import Path
from threading import Lock

import flask

parser = argparse.ArgumentParser(description="Video Downloader web server")
parser.add_argument("--port", type=int, default=6060)
parser.add_argument("--subdomain", type=str, default="/videodl")
args, _ = parser.parse_known_args()

SUBDOMAIN = args.subdomain.rstrip("/")
TEMP_ROOT = Path("/tmp/videodl")
TEMP_ROOT.mkdir(parents=True, exist_ok=True)

SETTINGS_ROOT = Path.home() / "configs" / "VideoDownloader"
SETTINGS_ROOT.mkdir(parents=True, exist_ok=True)
COOKIES_FILE = SETTINGS_ROOT / "cookies.txt"

app = flask.Flask(__name__, static_url_path=SUBDOMAIN)
bp = flask.Blueprint("videodl", __name__)

_sessions: dict[str, Path] = {}
_lock = Lock()


def _download_video(url: str, dest: Path) -> dict:
    """Download video at url into dest using yt-dlp. Returns metadata dict."""
    dest.mkdir(parents=True, exist_ok=True)

    base_cmd = ["yt-dlp", "--no-playlist"]
    if COOKIES_FILE.exists():
        base_cmd += ["--cookies", str(COOKIES_FILE)]

    # Get title without downloading
    info_proc = subprocess.run(
        base_cmd + ["--dump-single-json", url],
        capture_output=True, text=True, timeout=30,
    )
    title = "video"
    if info_proc.returncode == 0 and info_proc.stdout.strip():
        try:
            title = json.loads(info_proc.stdout).get("title", "video")
        except Exception:
            pass

    # Download and merge to mp4
    subprocess.run(
        base_cmd + ["--merge-output-format", "mp4", "-P", str(dest), "-o", "%(id)s.%(ext)s", url],
        timeout=600, check=True,
    )

    mp4_files = list(dest.glob("*.mp4"))
    if not mp4_files:
        raise ValueError("Download completed but no mp4 found")

    mp4 = mp4_files[0]
    return {"file": mp4.name, "path": str(mp4), "title": title}


@bp.route("/")
def index():
    return flask.send_file(
        os.path.join(os.path.dirname(__file__), "templates", "index.html")
    )


@bp.route("/api/fetch", methods=["POST"])
def fetch():
    data = flask.request.get_json() or {}
    url = (data.get("url") or "").strip()
    if not url:
        return flask.jsonify({"error": "Missing URL"}), 400

    token = str(uuid.uuid4())
    dest = TEMP_ROOT / token
    try:
        result = _download_video(url, dest)
    except subprocess.CalledProcessError as exc:
        shutil.rmtree(dest, ignore_errors=True)
        stderr = (exc.stderr or "").strip()
        return flask.jsonify({"error": stderr[-500:] if stderr else "yt-dlp failed"}), 500
    except Exception as exc:
        shutil.rmtree(dest, ignore_errors=True)
        return flask.jsonify({"error": str(exc)}), 500

    with _lock:
        _sessions[token] = Path(result["path"])

    return flask.jsonify({"token": token, "title": result["title"], "filename": result["file"]})


@bp.route("/api/stream/<token>")
def stream(token: str):
    with _lock:
        path = _sessions.get(token)
    if not path or not path.exists():
        flask.abort(404)
    return flask.send_file(str(path), mimetype="video/mp4")


@bp.route("/api/client-download/<token>")
def client_download(token: str):
    with _lock:
        path = _sessions.pop(token, None)
    if not path or not path.exists():
        flask.abort(404)
    response = flask.send_file(
        str(path), mimetype="video/mp4", as_attachment=True, download_name=path.name,
    )

    @response.call_on_close
    def _cleanup():
        shutil.rmtree(path.parent, ignore_errors=True)

    return response


@bp.route("/api/save-to-server", methods=["POST"])
def save_to_server():
    data = flask.request.get_json() or {}
    token = data.get("token", "")
    dest_dir = (data.get("path") or "").strip()

    with _lock:
        src_path = _sessions.pop(token, None)
    if not src_path or not src_path.exists():
        return flask.jsonify({"error": "Session not found or expired"}), 404
    if not dest_dir or not os.path.isdir(dest_dir):
        return flask.jsonify({"error": "Invalid destination directory"}), 400

    dest_path = Path(dest_dir) / src_path.name
    shutil.move(str(src_path), str(dest_path))
    shutil.rmtree(src_path.parent, ignore_errors=True)
    return flask.jsonify({"success": True, "saved_to": str(dest_path)})


@bp.route("/api/list-dirs", methods=["POST"])
def list_dirs():
    data = flask.request.get_json() or {}
    path = os.path.normpath(data.get("path", "/"))
    try:
        entries = os.listdir(path)
        dirs = sorted(e for e in entries if os.path.isdir(os.path.join(path, e)) and not e.startswith("."))
        hidden = sorted(e for e in entries if os.path.isdir(os.path.join(path, e)) and e.startswith("."))
        parent = os.path.dirname(path) if path != "/" else None
        return flask.jsonify({"path": path, "parent": parent, "dirs": dirs + hidden})
    except PermissionError:
        return flask.jsonify({"error": "Permission denied"}), 403
    except FileNotFoundError:
        return flask.jsonify({"error": "Path not found"}), 404


app.register_blueprint(bp, url_prefix=SUBDOMAIN)


def run():
    app.run(host="127.0.0.1", port=args.port, debug=False)


if __name__ == "__main__":
    run()
