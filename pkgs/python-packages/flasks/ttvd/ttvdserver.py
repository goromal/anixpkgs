"""TTVD Flask server — TikTok video downloader UI."""
import argparse
import asyncio
import os
import shutil
import uuid
from pathlib import Path
from threading import Lock

import flask

parser = argparse.ArgumentParser(description="TTVD web server")
parser.add_argument("--port", type=int, default=6060)
parser.add_argument("--subdomain", type=str, default="/ttvd")
args, _ = parser.parse_known_args()

SUBDOMAIN = args.subdomain.rstrip("/")
TEMP_ROOT = Path("/tmp/ttvd")
TEMP_ROOT.mkdir(parents=True, exist_ok=True)

# Persistent directory for TikTokDownloader settings (including cookies).
# Mirrors the CLI path so settings/cookies are shared and sync via rcrsync.
SETTINGS_ROOT = Path.home() / "configs" / "TikTokDownloader"
SETTINGS_ROOT.mkdir(parents=True, exist_ok=True)

app = flask.Flask(__name__, static_url_path=SUBDOMAIN)
bp = flask.Blueprint("ttvd", __name__)

_sessions: dict[str, Path] = {}
_lock = Lock()


def _build_parameter(root: Path):
    """Construct a minimal Parameter for unauthenticated public-video download.

    Actual signatures discovered from TikTokDownloader 5.8:
      Database()                                     -- no args
      DownloadRecorder(database, switch, console)
      Cookie(settings, console)
      Parameter(settings, cookie_object, logger=..., console=..., **cfg, recorder=...)
    """
    from src.tools import ColorfulConsole
    from src.config import Settings, Parameter
    from src.manager import Database, DownloadRecorder
    from src.record import BaseLogger

    root.mkdir(parents=True, exist_ok=True)
    console = ColorfulConsole()
    # Use persistent settings dir so cookies survive across requests/restarts.
    # The download root is overridden below to the per-request temp dir.
    settings = Settings(SETTINGS_ROOT, console)
    cfg = settings.read()

    # Override key settings for our use case
    cfg["root"] = str(root)
    cfg["download"] = True
    cfg["music"] = False
    cfg["folder_mode"] = False
    cfg["storage_format"] = ""  # no data export (BaseTextLogger no-op)

    db = Database()
    recorder = DownloadRecorder(db, False, console)

    return Parameter(
        settings,
        cfg.get("cookie", ""),                             # Douyin cookie (str)
        logger=BaseLogger,
        console=console,
        **cfg,
        recorder=recorder,
    )


async def _download_tiktok(url: str, dest: Path) -> dict:
    """Full pipeline: URL → mp4 in dest. Returns metadata dict.

    Pipeline (TikTokDownloader 5.8):
      1. LinkExtractor(params, tiktok=True).run(url) → list[str] of video IDs
      2. Detail(params, cookie, proxy, detail_id).run() → raw metadata
      3. Extractor(params).run([raw_data], record, tiktok=True) → processed list[dict]
      4. Downloader(params).run(processed, "detail", tiktok=True) → mp4 in params.root
    """
    from src.link import ExtractorTikTok
    from src.interface import DetailTikTok
    from src.extract import Extractor
    from src.downloader import Downloader
    from src.storage import RecordManager

    params = _build_parameter(dest)
    # Load cookies into HTTP headers (reads cookie_tiktok from settings and injects
    # into headers_tiktok; without this call the requests are unauthenticated).
    await params.update_params()

    # Step 1: extract video IDs from URL
    link_extractor = ExtractorTikTok(params)
    ids = await link_extractor.run(url)
    if not ids or not any(ids):
        raise ValueError("Could not extract video ID from URL")
    # ids may be list[str] or tuple(bool, list[str], list[str|None])
    if isinstance(ids, tuple):
        _, id_list, _ = ids
        video_id = id_list[0] if id_list else None
    else:
        video_id = ids[0]
    if not video_id:
        raise ValueError("No video ID found in URL")

    # Step 2: fetch raw video metadata
    # Detail(params, cookie='', proxy=None, detail_id=...)
    detail = DetailTikTok(params, "", None, video_id)
    raw_data = await detail.run()
    if not raw_data:
        raise ValueError("No metadata returned for this video (may require login or be geo-blocked)")

    # Step 3: process metadata through Extractor
    # Need a record context for the extractor
    record_mgr = RecordManager()
    root, logger_params, LoggerClass = record_mgr.run(params)
    async with LoggerClass(root, console=params.console, **logger_params) as record:
        extractor = Extractor(params)
        processed = await extractor.run([raw_data], record, tiktok=True)
        if not processed:
            raise ValueError("Could not process video metadata")

        # Step 4: download the video
        downloader = Downloader(params)
        await downloader.run(processed, "detail", tiktok=True)

    # Find the downloaded mp4 (placed under dest / folder_name)
    mp4_files = list(dest.glob("**/*.mp4"))
    if not mp4_files:
        raise ValueError("Download completed but no mp4 file found under temp dir")

    mp4 = mp4_files[0]
    title = processed[0].get("desc", "") or mp4.stem

    return {
        "file": mp4.name,
        "path": str(mp4),
        "title": title,
    }


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
        result = asyncio.run(_download_tiktok(url, dest))
    except Exception as exc:
        shutil.rmtree(dest, ignore_errors=True)
        return flask.jsonify({"error": str(exc)}), 500

    with _lock:
        _sessions[token] = Path(result["path"])

    return flask.jsonify({
        "token": token,
        "title": result["title"],
        "filename": result["file"],
    })


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
        str(path),
        mimetype="video/mp4",
        as_attachment=True,
        download_name=path.name,
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
        dirs = sorted(
            e for e in entries
            if os.path.isdir(os.path.join(path, e)) and not e.startswith(".")
        )
        hidden = sorted(
            e for e in entries
            if os.path.isdir(os.path.join(path, e)) and e.startswith(".")
        )
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
