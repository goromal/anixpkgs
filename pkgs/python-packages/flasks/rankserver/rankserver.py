import os
import json
import sys
import hashlib
import argparse
import flask
from PIL import Image
import flask_login
import flask_wtf
from wtforms import StringField, PasswordField, SubmitField
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import timedelta
from pysorting import (
    ComparatorLeft,
    ComparatorResult,
    QuickSortState,
    persistStateToDisk,
    sortStateFromDisk,
    restfulQuickSort,
)

UINT32_MAX = 0xffffffff
LOGNAME = "sort_state.log"
MAPNAME = "file_map.log"

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--subdomain", action="store", type=str, default="/rank", help="Subdomain for a reverse proxy")
parser.add_argument("--data-dir", action="store", type=str, default="", help="Directory containing the rankable elements")
parser.add_argument("--secrets-file", action="store", type=str, required=True, help="Path to JSON file with secret_key and password_hash")
args = parser.parse_args()


def _load_secrets(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except OSError as e:
        sys.exit(f"rankserver: cannot read secrets file {path}: {e}")
    except json.JSONDecodeError as e:
        sys.exit(f"rankserver: invalid JSON in secrets file {path}: {e}")
    missing = [k for k in ("secret_key", "password_hash") if not data.get(k)]
    if missing:
        sys.exit(f"rankserver: secrets file {path} missing keys: {', '.join(missing)}")
    return data


_secrets = _load_secrets(args.secrets_file)

urlroot = args.subdomain
if urlroot != "/":
    urlroot += "/"
url_for_prefix = args.subdomain.replace("/", "")
if len(url_for_prefix) > 0:
    url_for_prefix += "."

bp = flask.Blueprint("rank", __name__, url_prefix=args.subdomain)

class LoginForm(flask_wtf.FlaskForm):
    username = StringField("Username")
    password = PasswordField("Password")
    submit = SubmitField("Submit")

class User(flask_login.UserMixin):
    def check_password(self, password):
        return check_password_hash(_secrets["password_hash"], password)
    def get_id(self):
        return "anonymous"

user = User()

PWD = os.getcwd()
if args.data_dir[0] == '/':
    RES_DIR = args.data_dir
else:
    RES_DIR = os.path.join(PWD, args.data_dir)
SHORT_RESDIR = os.path.basename(os.path.realpath(RES_DIR))
# Cache thumbnails inside the rankables directory itself. RES_DIR is the symlink
# path, so this always resolves into whatever directory is currently linked —
# each rankable directory keeps its own persistent cache, and re-pointing the
# symlink moves the cache with it. Hidden + a directory, so load()'s .txt/.png
# scan of RES_DIR never picks it up.
THUMB_CACHE = os.path.join(RES_DIR, ".rankthumbs")

app = flask.Flask(__name__, static_url_path=args.subdomain, static_folder=RES_DIR)
app.secret_key = _secrets["secret_key"].encode()
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(minutes=20)
login_manager = flask_login.LoginManager()

class RankServer:
    def __init__(self):
        self.logfilename = None
        self.mapfilename = None
        self.file_map = []
        self.state = None
        self.rank_list = []
        self.rev_rank_list = []

    def load(self):
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
        files = []
        for file in os.listdir(RES_DIR):
            if file.endswith(".txt") or file.endswith(".png"):
                files.append(file)
        if len(files) == 0:
            return (False, "Data directory has no rankable files (.txt|.png)")
        self.mapfilename = os.path.join(RES_DIR, MAPNAME)
        if not os.path.exists(self.mapfilename):
            self.file_map = files
        else:
            self.file_map = []
            with open(self.mapfilename, "r") as mapfile:
                for file in mapfile:
                    if len(file.strip()) > 0:
                        self.file_map.append(file.strip())
            if len(self.file_map) == 0:
                return (False, "Empty file map in provided data dir")
            # TODO check for incongruencies
        self.logfilename = os.path.join(RES_DIR, LOGNAME)
        if not os.path.exists(self.logfilename):
            self.state = QuickSortState()
            self.state.n = len(self.file_map)
            self.state.arr = [i for i in range(self.state.n)]
            self.state.stack = [0 for _ in range(self.state.n)]
            self.submitChoice(0)
        else:
            res, self.state = sortStateFromDisk(self.logfilename)
            if not res:
                return (False, "Sort state loading from file failed")
            # TODO check for incongruencies
        self.rank_list = []
        for idx in self.state.arr:
            self.rank_list.append(self.file_map[idx])
        self.rev_rank_list = self.rank_list[::-1]
        return (True, "")
    
    def resetState(self):
        reset_state = QuickSortState()
        reset_state.n = self.state.n
        reset_state.arr = self.state.arr
        reset_state.stack = [0 for _ in range(self.state.n)]
        self.state = reset_state
        self.submitChoice(0)
    
    def sortingComplete(self):
        return self.state.sorted == 1
    
    def getRankList(self):
        return self.rev_rank_list

    def getCompFiles(self):
        rightfile = self.file_map[self.state.arr[self.state.p]]
        if self.state.l == int(ComparatorLeft.I):
            leftfile = self.file_map[self.state.arr[self.state.i]]
        else:
            leftfile = self.file_map[self.state.arr[self.state.j]]
        return (leftfile, rightfile)
    
    def submitChoice(self, enum_int):
        full_step = False
        max_iter = 50
        i = 0
        self.state.c = enum_int
        while not full_step and i < max_iter:
            res, state_out = restfulQuickSort(self.state)
            if not res:
                return (False, "RESTful sort step failed")
            self.state = state_out
            if self.state.sorted == 1:
                full_step = True
            elif self.state.p == (self.state.i if self.state.l == int(ComparatorLeft.I) else self.state.j):
                self.state.c = int(ComparatorResult.LEFT_EQUAL)
            else:
                full_step = True
            i += 1
        if not full_step:
            return (False, "RESTful sort timed out with incomplete steps")
        return (True, "")

    def save(self):
        with open(self.mapfilename, "w") as mapfile:
            for file in self.file_map:
                mapfile.write(f"{file}\n")
        if not persistStateToDisk(self.logfilename, self.state):
            return (False, "Failed to persist sort state to disk")
        return (True, "")

rankserver = RankServer()

@login_manager.user_loader
def load_user(user_id):
    global user
    if user_id == "anonymous":
        return user
    else:
        return None

@bp.route("/login", methods=["GET", "POST"])
def login():
    global user
    global url_for_prefix
    if flask_login.current_user.is_authenticated:
        return flask.redirect(flask.url_for(url_for_prefix + 'index'))
    form = LoginForm()
    if form.validate_on_submit():
        if form.username.data == "admin":
            return flask.redirect("/grafana")
        if form.username.data != user.get_id() or not user.check_password(form.password.data):
            return flask.redirect(flask.url_for(url_for_prefix + "login"))
        flask_login.login_user(user, remember=False)
        flask.session.permanent = True
        next = flask.request.args.get('next')
        return flask.redirect(next or flask.url_for(url_for_prefix + 'intro'))
    return flask.render_template("login.html", title="Sign In", form=form)
      
@bp.route("/logout")
@flask_login.login_required
def logout():
    global url_for_prefix
    flask_login.logout_user()
    return flask.redirect(flask.url_for(url_for_prefix + "login"))

@bp.route("/", methods=["GET","POST"])
@flask_login.login_required
def index():
    global args
    global rankserver
    global urlroot
    if flask.request.method == "POST":
        if rankserver.sortingComplete():
            rankserver.resetState()
        else:
            if "choose_l" in flask.request.form:
                rankserver.submitChoice(int(ComparatorResult.LEFT_GREATER))
            else:
                rankserver.submitChoice(int(ComparatorResult.LEFT_LESS))
        rankserver.save()
    
    res, msg = rankserver.load()
    if not res:
        return flask.render_template("index.html", urlroot=urlroot, intro=False, datadir=SHORT_RESDIR, err=True, done=False, msg=msg, rlist=[], l="", r="")
    rlist = rankserver.getRankList()
    if rankserver.sortingComplete():
        return flask.render_template("index.html", urlroot=urlroot, intro=False, datadir=SHORT_RESDIR, err=False, done=True, msg="", rlist=rlist, l="", r="")
    else:
        l, r = rankserver.getCompFiles()
        return flask.render_template("index.html", urlroot=urlroot, intro=False, datadir=SHORT_RESDIR, err=False, done=False, msg="", rlist=rlist, l=l, r=r)

@bp.route("/intro", methods=["GET"])
@flask_login.login_required
def intro():
    global urlroot
    global SHORT_RESDIR
    return flask.render_template("index.html", urlroot=urlroot, intro=True, datadir=SHORT_RESDIR, err=False, done=False, msg="", rlist=[], l="", r="")

@bp.route("/api/rankables-info", methods=["GET"])
@flask_login.login_required
def rankables_info():
    is_link = os.path.islink(RES_DIR)
    realpath = os.path.realpath(RES_DIR)
    return flask.jsonify({
        'is_symlink': is_link,
        'symlink_path': RES_DIR,
        'real_path': realpath
    })

@bp.route("/api/list-dirs", methods=["POST"])
@flask_login.login_required
def list_dirs():
    data = flask.request.get_json()
    path = os.path.normpath(data.get('path', '/'))
    try:
        entries = os.listdir(path)
        dirs = sorted([e for e in entries if os.path.isdir(os.path.join(path, e)) and not e.startswith('.')])
        hidden_dirs = sorted([e for e in entries if os.path.isdir(os.path.join(path, e)) and e.startswith('.')])
        parent = os.path.dirname(path) if path != '/' else None
        return flask.jsonify({'path': path, 'parent': parent, 'dirs': dirs + hidden_dirs})
    except PermissionError:
        return flask.jsonify({'error': 'Permission denied'}), 403
    except FileNotFoundError:
        return flask.jsonify({'error': 'Path not found'}), 404

@bp.route("/api/set-rankables-dir", methods=["POST"])
@flask_login.login_required
def set_rankables_dir():
    global SHORT_RESDIR
    data = flask.request.get_json()
    new_target = data.get('path')
    if not new_target:
        return flask.jsonify({'success': False, 'error': 'Missing path parameter'}), 400
    new_target = os.path.normpath(new_target)
    if not os.path.isdir(new_target):
        return flask.jsonify({'success': False, 'error': 'Path is not a directory'}), 400
    if not os.path.islink(RES_DIR):
        return flask.jsonify({'success': False, 'error': 'Rankables path is not a symlink; cannot reroute'}), 400
    try:
        os.unlink(RES_DIR)
        os.symlink(new_target, RES_DIR)
        SHORT_RESDIR = os.path.basename(os.path.realpath(RES_DIR))
        return flask.jsonify({'success': True, 'real_path': new_target})
    except Exception as e:
        return flask.jsonify({'success': False, 'error': str(e)}), 500

@bp.route("/thumb/<path:filename>", methods=["GET"])
@flask_login.login_required
def thumb(filename):
    # Downscaled, disk-cached thumbnail. Lets the ranking page show many images
    # without downloading every full-resolution file. Cache key includes mtime
    # and size so edits (rotate/crop elsewhere) invalidate stale thumbnails.
    safe = os.path.basename(filename)
    if safe != filename or not safe.lower().endswith(".png"):
        flask.abort(404)
    src = os.path.join(RES_DIR, safe)
    if not os.path.isfile(src):
        flask.abort(404)
    try:
        w = int(flask.request.args.get("w", 240))
    except (TypeError, ValueError):
        w = 240
    w = max(16, min(w, 2000))
    st = os.stat(src)
    key = hashlib.sha1(
        f"{os.path.realpath(src)}|{st.st_mtime_ns}|{st.st_size}|{w}".encode()
    ).hexdigest()
    cached = os.path.join(THUMB_CACHE, key + ".png")
    if not os.path.exists(cached):
        try:
            os.makedirs(THUMB_CACHE, exist_ok=True)
            img = Image.open(src)
            img.thumbnail((w, 100000000), Image.LANCZOS)
            tmp = cached + ".tmp"
            img.save(tmp, format="PNG")
            os.replace(tmp, cached)
        except Exception:
            # Fall back to the original on any cache/decode/encode failure.
            return flask.send_file(src, mimetype="image/png", max_age=86400)
    return flask.send_file(cached, mimetype="image/png", max_age=86400)

@app.before_request
def refresh_session():
    flask.session.permanent = True
    flask.session.modified = True

def run():
    global args
    app.register_blueprint(bp)
    login_manager.init_app(app)
    login_manager.login_view = "rank.login"
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
