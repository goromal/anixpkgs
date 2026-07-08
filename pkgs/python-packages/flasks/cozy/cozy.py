import argparse
import json
import os
import shlex
import subprocess
import sys

import flask
import flask_login
import flask_wtf
from datetime import timedelta
from werkzeug.security import check_password_hash
from wtforms import PasswordField, StringField, SubmitField

from comfyui_client import ComfyUIClient
from job_store import JobStore, job_duration

_PW_HASH = None  # populated from the secrets file at startup; see _load_secrets


def _load_secrets(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except OSError as e:
        sys.exit(f"cozy: cannot read secrets file {path}: {e}")
    except json.JSONDecodeError as e:
        sys.exit(f"cozy: invalid JSON in secrets file {path}: {e}")
    missing = [k for k in ("secret_key", "password_hash") if not data.get(k)]
    if missing:
        sys.exit(f"cozy: secrets file {path} missing keys: {', '.join(missing)}")
    return data


def _check_password(password):
    return check_password_hash(_PW_HASH, password)


_IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")

# ComfyUI's LoadImage resolves an `image` value ending in this suffix against
# its output directory instead of the input directory (folder_paths
# .annotated_filepath). cozy uses the same suffix as the picker option value for
# output-dir files, so the same string is the LoadImage input, the persisted
# selection, and the preview key -- no conversion anywhere.
_OUTPUT_SUFFIX = " [output]"


def _list_dir_images(directory):
    """Sorted relative paths of image files under directory (empty if unset)."""
    out = []
    if not directory:
        return out
    for root, _dirs, files in os.walk(directory):
        for f in files:
            if f.lower().endswith(_IMAGE_EXTS):
                out.append(os.path.relpath(os.path.join(root, f), directory))
    return sorted(out)


def _list_images(input_dir, output_dir):
    """Picker options spanning the input and output dirs. Each option's `value`
    is what gets sent to ComfyUI's LoadImage `image` input: a bare relative path
    for input-dir files, suffixed with ' [output]' for output-dir files (so a
    prior generation can be re-fed as the edit input). `label` is the bare path
    for display; `source` groups the two in the UI."""
    items = [{"value": r, "label": r, "source": "input"}
             for r in _list_dir_images(input_dir)]
    items += [{"value": r + _OUTPUT_SUFFIX, "label": r, "source": "output"}
              for r in _list_dir_images(output_dir)]
    return items


def _resolve_image_ref(input_dir, output_dir, value):
    """Map a picker value to an on-disk path, or None if it is not a valid image
    within the directory it names. Output-dir files carry the ' [output]'
    annotation; everything else resolves under the input dir. Rejects traversal
    out of the chosen base via realpath containment."""
    if not value:
        return None
    if value.endswith(_OUTPUT_SUFFIX):
        base, rel = output_dir, value[:-len(_OUTPUT_SUFFIX)]
    else:
        base, rel = input_dir, value
    if not base or not rel.lower().endswith(_IMAGE_EXTS):
        return None
    full = os.path.realpath(os.path.join(base, rel))
    root = os.path.realpath(base)
    if os.path.commonpath([full, root]) != root or not os.path.isfile(full):
        return None
    return full


class LoginForm(flask_wtf.FlaskForm):
    username = StringField("Username")
    password = PasswordField("Password")
    submit = SubmitField("Submit")


class User(flask_login.UserMixin):
    def get_id(self):
        return "anonymous"


def create_app(store, workflows, workflow_dir, subdomain="/cozy",
               input_dir=None, output_dir=None, workflow_kinds=None,
               secret_key=None, password_hash=None, restart_cmd=None):
    global _PW_HASH
    if password_hash is not None:
        _PW_HASH = password_hash
    input_dir = input_dir or os.path.join(workflow_dir, "input")
    output_dir = output_dir or os.path.join(workflow_dir, "output")
    workflow_kinds = workflow_kinds or {}
    urlroot = subdomain if subdomain == "/" else subdomain + "/"
    prefix = subdomain.replace("/", "")
    prefix = prefix + "." if prefix else ""
    static_url_path = (subdomain.rstrip("/") or "") + "/static"

    app = flask.Flask(__name__, static_url_path=static_url_path, static_folder="static")
    app.secret_key = secret_key or os.urandom(24)
    app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(minutes=20)
    app.config.setdefault("WTF_CSRF_ENABLED", True)

    login_manager = flask_login.LoginManager()
    user = User()

    @login_manager.user_loader
    def load_user(user_id):
        return user if user_id == "anonymous" else None

    bp = flask.Blueprint("cozy", __name__, url_prefix=subdomain)

    @bp.route("/login", methods=["GET", "POST"])
    def login():
        if flask_login.current_user.is_authenticated:
            return flask.redirect(flask.url_for(prefix + "index"))
        form = LoginForm()
        if form.validate_on_submit():
            if form.username.data != user.get_id() or not _check_password(form.password.data):
                return flask.redirect(flask.url_for(prefix + "login"))
            flask_login.login_user(user, remember=False)
            flask.session.permanent = True
            return flask.redirect(flask.url_for(prefix + "index"))
        return flask.render_template("login.html", title="Sign In", form=form)

    @bp.route("/logout")
    @flask_login.login_required
    def logout():
        flask_login.logout_user()
        return flask.redirect(flask.url_for(prefix + "login"))

    @bp.route("/", methods=["GET"])
    @flask_login.login_required
    def index():
        state = store.read_state()
        state["job"]["duration"] = job_duration(state["job"])
        return flask.render_template(
            "index.html", urlroot=urlroot, workflows=workflows, state=state,
            workflow_kinds=workflow_kinds, can_restart=bool(restart_cmd))

    @bp.route("/api/generate", methods=["POST"])
    @flask_login.login_required
    def generate():
        data = flask.request.get_json(force=True, silent=True) or {}
        wf = data.get("workflow")
        if wf not in workflows:
            return flask.jsonify({"error": "unknown workflow"}), 400
        prompt = data.get("prompt", "")
        image = data.get("image", "") or ""
        if workflow_kinds.get(wf) == "edit":
            if not _resolve_image_ref(input_dir, output_dir, image):
                return flask.jsonify({"error": "valid input image required"}), 400
        try:
            width = int(data.get("width", 400))
            height = int(data.get("height", 800))
        except (TypeError, ValueError):
            return flask.jsonify({"error": "invalid dimensions"}), 400
        path = os.path.join(workflow_dir, wf + ".api.json")
        if not os.path.exists(path):
            return flask.jsonify({"error": "workflow file missing"}), 400
        if not store.start(wf, path, prompt, width, height, image):
            return flask.jsonify({"error": "already running"}), 409
        return flask.jsonify({"ok": True})

    @bp.route("/api/status", methods=["GET"])
    @flask_login.login_required
    def status():
        state = store.read_state()
        job = state["job"]
        return flask.jsonify({
            "status": job["status"],
            "progress": job.get("progress", 0),
            "error": job.get("error"),
            "has_image": bool(state.get("output")),
            "duration": job_duration(job),
        })

    @bp.route("/api/image", methods=["GET"])
    @flask_login.login_required
    def image():
        if not os.path.exists(store.image_path):
            return flask.jsonify({"error": "no image"}), 404
        return flask.send_file(store.image_path, mimetype="image/png")

    @bp.route("/api/input-images", methods=["GET"])
    @flask_login.login_required
    def input_images():
        return flask.jsonify({"images": _list_images(input_dir, output_dir)})

    @bp.route("/api/input-image", methods=["GET"])
    @flask_login.login_required
    def input_image():
        full = _resolve_image_ref(input_dir, output_dir, flask.request.args.get("name", ""))
        if not full:
            return flask.jsonify({"error": "not found"}), 404
        return flask.send_file(full)

    @bp.route("/api/clear", methods=["POST"])
    @flask_login.login_required
    def clear():
        store.clear()
        return flask.jsonify({"ok": True})

    @bp.route("/api/restart-comfyui", methods=["POST"])
    @flask_login.login_required
    def restart_comfyui():
        if not restart_cmd:
            return flask.jsonify({"error": "restart not configured"}), 503
        try:
            subprocess.run(restart_cmd, check=True, timeout=30,
                           capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            return flask.jsonify({"error": (e.stderr or "").strip() or "restart failed"}), 500
        except Exception as e:
            return flask.jsonify({"error": str(e)}), 500
        return flask.jsonify({"ok": True})

    @bp.route("/api/flush", methods=["POST"])
    @flask_login.login_required
    def flush():
        # Run a flush.sh (if present) in the input and output dirs. The scripts
        # are placed there out-of-band by the admin; a missing one is a no-op, so
        # the button is always available and simply flushes whatever is wired up.
        ran = 0
        for d in (input_dir, output_dir):
            script = os.path.join(d, "flush.sh")
            if not os.path.isfile(script):
                continue
            try:
                subprocess.run(["bash", script], check=True, timeout=60,
                               capture_output=True, text=True, cwd=d)
            except subprocess.CalledProcessError as e:
                return flask.jsonify(
                    {"error": (e.stderr or "").strip() or f"flush failed in {d}"}), 500
            except Exception as e:
                return flask.jsonify({"error": str(e)}), 500
            ran += 1
        return flask.jsonify({"ok": True, "ran": ran})

    app.register_blueprint(bp)
    login_manager.init_app(app)
    login_manager.login_view = prefix + "login"

    @app.before_request
    def refresh_session():
        flask.session.permanent = True
        flask.session.modified = True

    return app


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5000, help="Port to run the server on")
    parser.add_argument("--subdomain", type=str, default="/", help="Subdomain for a reverse proxy")
    parser.add_argument("--comfyui-url", type=str, default="http://127.0.0.1:8188",
                        help="Base URL of the ComfyUI server")
    parser.add_argument("--state-dir", type=str, default="",
                        help="Directory for persisted cozy state")
    parser.add_argument("--workflow-dir", type=str, default="",
                        help="Directory containing <name>.api.json workflow files")
    parser.add_argument("--workflows", type=str, default="imggen,imggen2",
                        help="Comma-separated workflow names")
    parser.add_argument("--input-dir", type=str, default="",
                        help="Directory of selectable input images (default <workflow-dir>/input)")
    parser.add_argument("--output-dir", type=str, default="",
                        help="Directory of selectable output images for edit workflows "
                             "(default <workflow-dir>/output)")
    parser.add_argument("--secrets-file", type=str, required=True,
                        help="Path to JSON file with secret_key and password_hash")
    parser.add_argument("--comfyui-restart-cmd", type=str, default="",
                        help="Command run to restart ComfyUI (e.g. "
                             "'systemctl restart comfyui.service'); empty hides the restart button")
    args = parser.parse_args()

    state_dir = args.state_dir or os.path.join(os.getcwd(), "cozy-state")
    workflow_dir = args.workflow_dir or os.getcwd()
    names = [w for w in args.workflows.split(",") if w]
    input_dir = args.input_dir or os.path.join(workflow_dir, "input")
    output_dir = args.output_dir or os.path.join(workflow_dir, "output")
    import workflows as _wf
    workflow_kinds = {
        n: _wf.load_meta(os.path.join(workflow_dir, n + ".api.json"))["kind"]
        for n in names if os.path.exists(os.path.join(workflow_dir, n + ".api.json"))
    }
    store = JobStore(state_dir, ComfyUIClient(args.comfyui_url))
    secrets = _load_secrets(args.secrets_file)
    restart_cmd = shlex.split(args.comfyui_restart_cmd) if args.comfyui_restart_cmd else None
    app = create_app(store=store, workflows=names,
                     workflow_dir=workflow_dir, subdomain=args.subdomain,
                     input_dir=input_dir, output_dir=output_dir,
                     workflow_kinds=workflow_kinds,
                     secret_key=secrets["secret_key"].encode(),
                     password_hash=secrets["password_hash"],
                     restart_cmd=restart_cmd)
    app.run(host="0.0.0.0", port=args.port)


if __name__ == "__main__":
    run()
