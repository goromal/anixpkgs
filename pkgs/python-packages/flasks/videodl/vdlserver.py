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
_mp3_sessions: dict[str, Path] = {}
_lock = Lock()


def _download_video(url: str, dest: Path) -> dict:
    """Download video at url into dest using yt-dlp. Returns metadata dict."""
    dest.mkdir(parents=True, exist_ok=True)

    base_cmd = ["yt-dlp", "--no-playlist"]
    if COOKIES_FILE.exists():
        base_cmd += ["--cookies", str(COOKIES_FILE)]

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

    subprocess.run(
        base_cmd + ["--merge-output-format", "mp4", "-P", str(dest), "-o", "%(id)s.%(ext)s", url],
        timeout=600, check=True,
    )

    mp4_files = list(dest.glob("*.mp4"))
    if not mp4_files:
        raise ValueError("Download completed but no mp4 found")

    mp4 = mp4_files[0]
    return {"file": mp4.name, "path": str(mp4), "title": title}


def _get_video_duration(path: Path) -> float:
    """Return video duration in seconds using ffprobe."""
    result = subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", str(path)],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return 0.0
    try:
        return float(json.loads(result.stdout).get("format", {}).get("duration", 0))
    except Exception:
        return 0.0


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
        _mp3_sessions.pop(token, None)
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
        _mp3_sessions.pop(token, None)
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


@bp.route("/api/rotate-video", methods=["POST"])
def rotate_video():
    data = flask.request.get_json() or {}
    token = data.get("token", "")
    degrees = data.get("degrees")

    with _lock:
        path = _sessions.get(token)
    if not path or not path.exists():
        return flask.jsonify({"success": False, "error": "Session not found or expired"}), 404
    if degrees is None:
        return flask.jsonify({"success": False, "error": "Missing degrees parameter"}), 400

    normalized = ((int(degrees) % 360) + 360) % 360
    if normalized == 90:
        vf = "transpose=1"
    elif normalized == 270:
        vf = "transpose=2"
    elif normalized == 180:
        vf = "vflip,hflip"
    else:
        return flask.jsonify({"success": False, "error": f"Unsupported rotation: {degrees}°"}), 400

    temp_path = str(path) + ".tmp.mp4"
    result = subprocess.run(
        ["ffmpeg", "-i", str(path), "-vf", vf, "-c:a", "copy", temp_path, "-y"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        return flask.jsonify({"success": False, "error": f"ffmpeg error: {result.stderr[-500:]}"}), 500

    os.replace(temp_path, str(path))
    with _lock:
        _mp3_sessions.pop(token, None)
    return flask.jsonify({"success": True})


@bp.route("/api/crop-video", methods=["POST"])
def crop_video():
    data = flask.request.get_json() or {}
    token = data.get("token", "")
    x = data.get("x")
    y = data.get("y")
    width = data.get("width")
    height = data.get("height")

    with _lock:
        path = _sessions.get(token)
    if not path or not path.exists():
        return flask.jsonify({"success": False, "error": "Session not found or expired"}), 404
    if any(v is None for v in [x, y, width, height]):
        return flask.jsonify({"success": False, "error": "Missing crop parameters"}), 400
    if width <= 0 or height <= 0:
        return flask.jsonify({"success": False, "error": "Width and height must be positive"}), 400

    temp_path = str(path) + ".tmp.mp4"
    result = subprocess.run(
        ["ffmpeg", "-i", str(path), "-vf", f"crop={width}:{height}:{x}:{y}", "-c:a", "copy", temp_path, "-y"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        return flask.jsonify({"success": False, "error": f"ffmpeg error: {result.stderr[-500:]}"}), 500

    os.replace(temp_path, str(path))
    with _lock:
        _mp3_sessions.pop(token, None)
    return flask.jsonify({"success": True})


@bp.route("/api/trim-video", methods=["POST"])
def trim_video():
    data = flask.request.get_json() or {}
    token = data.get("token", "")
    edit_points = data.get("edit_points", [])

    with _lock:
        path = _sessions.get(token)
    if not path or not path.exists():
        return flask.jsonify({"success": False, "error": "Session not found or expired"}), 404
    if not edit_points:
        return flask.jsonify({"success": False, "error": "No edit points provided"}), 400

    duration = _get_video_duration(path)
    pts = sorted(edit_points, key=lambda p: p["time"])

    if pts[0]["type"] == "end":
        pts.insert(0, {"type": "start", "time": 0.0})
    if pts[-1]["type"] == "start":
        pts.append({"type": "end", "time": duration})

    segments = []
    i = 0
    while i < len(pts) - 1:
        if pts[i]["type"] == "start" and pts[i + 1]["type"] == "end":
            segments.append((pts[i]["time"], pts[i + 1]["time"]))
            i += 2
        else:
            return flask.jsonify({"success": False, "error": f"Invalid edit point sequence at index {i}: expected alternating start/end pairs"}), 400

    if not segments:
        return flask.jsonify({"success": False, "error": "No valid segments"}), 400

    probe = subprocess.run(
        ["ffprobe", "-v", "quiet", "-select_streams", "a",
         "-show_entries", "stream=codec_type", "-of", "default=noprint_wrappers=1", str(path)],
        capture_output=True, text=True,
    )
    has_audio = "codec_type=audio" in probe.stdout

    n = len(segments)
    filter_parts = []
    for idx, (start, end) in enumerate(segments):
        filter_parts.append(f"[0:v]trim=start={start}:end={end},setpts=PTS-STARTPTS[v{idx}]")
        if has_audio:
            filter_parts.append(f"[0:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[a{idx}]")

    temp_path = str(path) + ".tmp.mp4"
    if has_audio:
        stream_inputs = "".join(f"[v{i}][a{i}]" for i in range(n))
        filter_parts.append(f"{stream_inputs}concat=n={n}:v=1:a=1[vout][aout]")
        cmd = ["ffmpeg", "-i", str(path), "-filter_complex", ";".join(filter_parts),
               "-map", "[vout]", "-map", "[aout]", temp_path, "-y"]
    else:
        stream_inputs = "".join(f"[v{i}]" for i in range(n))
        filter_parts.append(f"{stream_inputs}concat=n={n}:v=1:a=0[vout]")
        cmd = ["ffmpeg", "-i", str(path), "-filter_complex", ";".join(filter_parts),
               "-map", "[vout]", temp_path, "-y"]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        if os.path.exists(temp_path):
            os.remove(temp_path)
        return flask.jsonify({"success": False, "error": f"ffmpeg error: {result.stderr[-500:]}"}), 500

    os.replace(temp_path, str(path))
    with _lock:
        _mp3_sessions.pop(token, None)
    return flask.jsonify({"success": True})


@bp.route("/api/screenshot/<token>")
def screenshot(token: str):
    timestamp_str = flask.request.args.get("t", "0")
    try:
        timestamp = float(timestamp_str)
    except ValueError:
        flask.abort(400)

    with _lock:
        path = _sessions.get(token)
    if not path or not path.exists():
        flask.abort(404)

    png_path = path.parent / f"{path.stem}_screenshot_{timestamp:.2f}.png"
    result = subprocess.run(
        ["ffmpeg", "-i", str(path), "-ss", str(timestamp), "-vframes", "1", str(png_path), "-y"],
        capture_output=True, text=True,
    )
    if result.returncode != 0 or not png_path.exists():
        flask.abort(500)

    response = flask.send_file(
        str(png_path), mimetype="image/png", as_attachment=True, download_name=png_path.name,
    )

    @response.call_on_close
    def _cleanup():
        png_path.unlink(missing_ok=True)

    return response


@bp.route("/api/convert-mp3", methods=["POST"])
def convert_mp3():
    data = flask.request.get_json() or {}
    token = data.get("token", "")

    with _lock:
        path = _sessions.get(token)
    if not path or not path.exists():
        return flask.jsonify({"success": False, "error": "Session not found or expired"}), 404

    mp3_path = path.with_suffix(".mp3")
    result = subprocess.run(
        ["ffmpeg", "-i", str(path), "-q:a", "0", "-map", "a", str(mp3_path), "-y"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        if mp3_path.exists():
            mp3_path.unlink()
        return flask.jsonify({"success": False, "error": f"ffmpeg error: {result.stderr[-500:]}"}), 500

    with _lock:
        _mp3_sessions[token] = mp3_path
    return flask.jsonify({"success": True})


@bp.route("/api/client-download-mp3/<token>")
def client_download_mp3(token: str):
    with _lock:
        mp3_path = _mp3_sessions.pop(token, None)
    if not mp3_path or not mp3_path.exists():
        flask.abort(404)

    response = flask.send_file(
        str(mp3_path), mimetype="audio/mpeg", as_attachment=True, download_name=mp3_path.name,
    )

    @response.call_on_close
    def _cleanup():
        mp3_path.unlink(missing_ok=True)

    return response


app.register_blueprint(bp, url_prefix=SUBDOMAIN)


def run():
    app.run(host="127.0.0.1", port=args.port, debug=False)


if __name__ == "__main__":
    run()
