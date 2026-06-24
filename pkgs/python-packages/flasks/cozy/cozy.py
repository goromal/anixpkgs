import argparse
import os

import flask
import flask_login
import flask_wtf
from datetime import timedelta
from werkzeug.security import check_password_hash
from wtforms import PasswordField, StringField, SubmitField

from comfyui_client import ComfyUIClient
from job_store import JobStore, job_duration

# Identical to stampserver's credential hash + secret key.
_PW_HASH = ("scrypt:32768:8:1$acPu0meyxPfx0SnS$26a570af250e0593c2dbb6bfb1d037a7"
            "366109a0ba4886e68191237efdabb2fca07de6c81c337b5e275390c2d7ff96f3"
            "455f47b7a05027a7e0ebf1628f537498")
_SECRET_KEY = b"71d2dcdb895b367a1d5f0c66ca559c8d69af0c29a7e101c18c7c2d10399f264e"


def _check_password(password):
    return check_password_hash(_PW_HASH, password)


_IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp")


def _list_input_images(input_dir):
    """Relative paths of image files under input_dir, sorted."""
    out = []
    for root, _dirs, files in os.walk(input_dir):
        for f in files:
            if f.lower().endswith(_IMAGE_EXTS):
                out.append(os.path.relpath(os.path.join(root, f), input_dir))
    return sorted(out)


def _safe_input_path(input_dir, name):
    """Resolve name under input_dir, or None if it escapes or is not an image."""
    if not name or not name.lower().endswith(_IMAGE_EXTS):
        return None
    full = os.path.realpath(os.path.join(input_dir, name))
    base = os.path.realpath(input_dir)
    if os.path.commonpath([full, base]) != base or not os.path.isfile(full):
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
               input_dir=None, workflow_kinds=None):
    input_dir = input_dir or os.path.join(workflow_dir, "input")
    workflow_kinds = workflow_kinds or {}
    urlroot = subdomain if subdomain == "/" else subdomain + "/"
    prefix = subdomain.replace("/", "")
    prefix = prefix + "." if prefix else ""
    static_url_path = (subdomain.rstrip("/") or "") + "/static"

    app = flask.Flask(__name__, static_url_path=static_url_path, static_folder="static")
    app.secret_key = _SECRET_KEY
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
            workflow_kinds=workflow_kinds)

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
            if not _safe_input_path(input_dir, image):
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
        return flask.jsonify({"images": _list_input_images(input_dir)})

    @bp.route("/api/input-image", methods=["GET"])
    @flask_login.login_required
    def input_image():
        full = _safe_input_path(input_dir, flask.request.args.get("name", ""))
        if not full:
            return flask.jsonify({"error": "not found"}), 404
        return flask.send_file(full)

    @bp.route("/api/clear", methods=["POST"])
    @flask_login.login_required
    def clear():
        store.clear()
        return flask.jsonify({"ok": True})

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
    args = parser.parse_args()

    state_dir = args.state_dir or os.path.join(os.getcwd(), "cozy-state")
    workflow_dir = args.workflow_dir or os.getcwd()
    names = [w for w in args.workflows.split(",") if w]
    input_dir = args.input_dir or os.path.join(workflow_dir, "input")
    import workflows as _wf
    workflow_kinds = {
        n: _wf.load_meta(os.path.join(workflow_dir, n + ".api.json"))["kind"]
        for n in names if os.path.exists(os.path.join(workflow_dir, n + ".api.json"))
    }
    store = JobStore(state_dir, ComfyUIClient(args.comfyui_url))
    app = create_app(store=store, workflows=names,
                     workflow_dir=workflow_dir, subdomain=args.subdomain,
                     input_dir=input_dir, workflow_kinds=workflow_kinds)
    app.run(host="0.0.0.0", port=args.port)


if __name__ == "__main__":
    run()
