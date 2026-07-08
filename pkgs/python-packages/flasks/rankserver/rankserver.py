import os
import json
import sys
import hashlib
import argparse
import subprocess
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
import rankops

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
# Remember where the symlink pointed at startup so the UI can reset back to it.
DEFAULT_TARGET = os.path.realpath(RES_DIR)
# Cache thumbnails inside the rankables directory itself. RES_DIR is the symlink
# path, so this always resolves into whatever directory is currently linked —
# each rankable directory keeps its own persistent cache, and re-pointing the
# symlink moves the cache with it. Hidden + a directory, so load()'s .txt/.png
# scan of RES_DIR never picks it up.
THUMB_CACHE = os.path.join(RES_DIR, ".rankthumbs")


def load_config():
    """Read rank_config.json from the active data dir. Returns (cfg, warning)."""
    path = os.path.join(RES_DIR, rankops.CONFIG_NAME)
    if not os.path.exists(path):
        return {"version": 1}, None
    try:
        with open(path) as f:
            return json.load(f), None
    except (OSError, json.JSONDecodeError) as e:
        # Report but never clobber a corrupt config file.
        return {"version": 1}, "rank_config.json unreadable ({}); watch disabled".format(e)


def save_config(cfg):
    path = os.path.join(RES_DIR, rankops.CONFIG_NAME)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cfg, f, indent=2)
    os.replace(tmp, path)


def _data_dir_entries(stamp_real):
    """Classify data-dir entries for rankops.plan_sync. A symlink is 'owned'
    when its target's parent directory resolves into the watched stamp dir."""
    entries = {}
    for name in os.listdir(RES_DIR):
        full = os.path.join(RES_DIR, name)
        if os.path.islink(full):
            target = os.readlink(full)
            if not os.path.isabs(target):
                target = os.path.join(os.path.dirname(full), target)
            entries[name] = {
                "type": "symlink",
                "owned": os.path.realpath(os.path.dirname(target)) == stamp_real,
                "dangling": not os.path.exists(full),
            }
        elif os.path.isdir(full):
            entries[name] = {"type": "dir"}
        else:
            entries[name] = {"type": "file"}
    return entries


def sync_symlinks(cfg):
    """Mirror tag-matching stamp files into RES_DIR as symlinks; prune owned
    dangling links. Returns a list of warning strings. Never raises."""
    watch = cfg.get("watch")
    if not watch:
        return []
    stamp_dir = watch.get("stamp_dir", "")
    tag = watch.get("stamp_tag", "")
    if not stamp_dir or not tag:
        return ["watch config incomplete; sync skipped"]
    try:
        stamp_files = os.listdir(stamp_dir)
    except OSError as e:
        # A vanished source must not tear down the working set.
        return ["stamp dir unreadable ({}); sync skipped".format(e)]
    stamp_real = os.path.realpath(stamp_dir)
    to_link, to_prune, warnings = rankops.plan_sync(
        stamp_files, _data_dir_entries(stamp_real), tag)
    for name in to_link:
        try:
            os.symlink(os.path.join(stamp_real, name), os.path.join(RES_DIR, name))
        except OSError as e:
            warnings.append("link failed for {}: {}".format(name, e))
    for name in to_prune:
        try:
            os.unlink(os.path.join(RES_DIR, name))
        except OSError as e:
            warnings.append("prune failed for {}: {}".format(name, e))
    return warnings


def state_to_dict(s):
    return {"sorted": s.sorted, "n": s.n, "arr": list(s.arr),
            "stack": list(s.stack), "top": s.top, "p": s.p, "i": s.i,
            "j": s.j, "l": s.l, "c": s.c}


def dict_to_state(d):
    s = QuickSortState()
    s.sorted = d["sorted"]; s.n = d["n"]; s.arr = list(d["arr"])
    s.stack = list(d["stack"]); s.top = d["top"]; s.p = d["p"]
    s.i = d["i"]; s.j = d["j"]; s.l = d["l"]; s.c = d["c"]
    return s


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
        self.config = {"version": 1}
        self.insertions = {"queue": [], "active": None}
        self.warnings = []

    def load(self):
        self.warnings = []
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
        cfg, cfg_warn = load_config()
        self.config = cfg
        if cfg_warn:
            self.warnings.append(cfg_warn)
        self.warnings += sync_symlinks(cfg)
        raw_ins = cfg.get("insertions") or {}
        self.insertions = {"queue": list(raw_ins.get("queue", [])),
                           "active": raw_ins.get("active")}
        files = [f.strip() for f in os.listdir(RES_DIR) if rankops.is_rankable(f)]
        if len(files) == 0:
            return (False, "Data directory has no rankable files (.txt|.png|.mp4)")
        self.mapfilename = os.path.join(RES_DIR, MAPNAME)
        self.logfilename = os.path.join(RES_DIR, LOGNAME)
        if not os.path.exists(self.mapfilename) or not os.path.exists(self.logfilename):
            # Fresh init: everything currently present becomes the settled set.
            self.file_map = files
            if self.insertions["queue"] or self.insertions["active"]:
                self.insertions = {"queue": [], "active": None}
                cfg["insertions"] = self.insertions
                save_config(cfg)
            self.state = QuickSortState()
            self.state.n = len(self.file_map)
            self.state.arr = [i for i in range(self.state.n)]
            self.state.stack = [0 for _ in range(self.state.n)]
            self.submitChoice(0)
        else:
            self.file_map = []
            with open(self.mapfilename, "r") as mapfile:
                for file in mapfile:
                    if len(file.strip()) > 0:
                        self.file_map.append(file.strip())
            if len(self.file_map) == 0:
                return (False, "Empty file map in provided data dir")
            res, self.state = sortStateFromDisk(self.logfilename)
            if not res:
                return (False, "Sort state loading from file failed")
            d, fmap, ins, result = rankops.reconcile(
                state_to_dict(self.state), self.file_map, set(files),
                self.insertions)
            if result["reset_all"]:
                os.remove(self.mapfilename)
                os.remove(self.logfilename)
                cfg["insertions"] = {"queue": [], "active": None}
                save_config(cfg)
                # The recursive load() resets self.warnings; keep this pass's
                # sync/config warnings visible alongside the fresh init's.
                carried = self.warnings
                res = self.load()
                self.warnings = carried + self.warnings
                return res
            if result["changed"]:
                ok, msg = rankops.validate_state(d, fmap)
                if not ok:
                    return (False,
                            "Sort state reconciliation failed ({}); on-disk "
                            "state left untouched. Delete {} and {} in the "
                            "data dir to reset the ranking.".format(
                                msg, LOGNAME, MAPNAME))
                self.state = dict_to_state(d)
                self.file_map = fmap
                sres, smsg = self.save()
                if not sres:
                    return (False, smsg)
                if result["partitions_restarted"]:
                    self.warnings.append(
                        "Removed file(s) overlapped the comparison in progress; "
                        "the current round was restarted")
            if ins != self.insertions:
                cfg["insertions"] = ins
                save_config(cfg)
            self.insertions = ins
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

    def insertionPending(self):
        return bool(self.insertions.get("queue") or self.insertions.get("active"))

    def insertionActive(self):
        return self.insertions.get("active") is not None

    def activateNextInsertion(self):
        ins = self.insertions
        fname = ins["queue"].pop(0)
        ins["active"] = {"file": fname, "lo": 0, "hi": self.state.n}
        self.config["insertions"] = ins
        save_config(self.config)

    def insertionCompFiles(self):
        a = self.insertions["active"]
        mid = rankops.insertion_mid(a)
        return (a["file"], self.file_map[self.state.arr[mid]])

    def submitInsertionChoice(self, prefer_new):
        a = self.insertions["active"]
        b = rankops.insertion_step(a, prefer_new)
        a["lo"], a["hi"] = b["lo"], b["hi"]
        if rankops.insertion_done(a):
            d, fmap = rankops.insertion_complete(
                state_to_dict(self.state), self.file_map, a["file"], a["lo"])
            self.state = dict_to_state(d)
            self.file_map = fmap
            sres, smsg = self.save()
            if not sres:
                # Persist nothing: the next load() re-reads the old on-disk
                # state and the unchanged config, so this tap is simply asked
                # again instead of silently re-queueing or double-inserting.
                return (False, "insertion save failed: {}".format(smsg))
            self.insertions["active"] = None
        self.config["insertions"] = self.insertions
        save_config(self.config)
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
    post_err = ""
    if flask.request.method == "POST":
        if rankserver.insertionActive():
            ires, imsg = rankserver.submitInsertionChoice(
                "choose_l" in flask.request.form)
            if not ires:
                post_err = imsg
        elif rankserver.sortingComplete():
            if not rankserver.insertionPending():
                rankserver.resetState()
                rankserver.save()
        else:
            if "choose_l" in flask.request.form:
                rankserver.submitChoice(int(ComparatorResult.LEFT_GREATER))
            else:
                rankserver.submitChoice(int(ComparatorResult.LEFT_LESS))
            rankserver.save()

    res, msg = rankserver.load()
    if post_err:
        # load() rebuilt self.warnings; re-attach the POST-time failure.
        rankserver.warnings.append(post_err)
    warn = " | ".join(rankserver.warnings)
    if not res:
        return flask.render_template("index.html", urlroot=urlroot, intro=False,
                                     datadir=SHORT_RESDIR, err=True, done=False,
                                     msg=msg, rlist=[], l="", r="", warn=warn,
                                     insert_note="")
    rlist = rankserver.getRankList()
    if rankserver.sortingComplete():
        if rankserver.insertionPending():
            if not rankserver.insertionActive():
                rankserver.activateNextInsertion()
            l, r = rankserver.insertionCompFiles()
            note = "Placing new file — {} more in queue".format(
                len(rankserver.insertions["queue"]))
            return flask.render_template("index.html", urlroot=urlroot,
                                         intro=False, datadir=SHORT_RESDIR,
                                         err=False, done=False, msg="",
                                         rlist=rlist, l=l, r=r, warn=warn,
                                         insert_note=note)
        return flask.render_template("index.html", urlroot=urlroot, intro=False,
                                     datadir=SHORT_RESDIR, err=False, done=True,
                                     msg="", rlist=rlist, l="", r="", warn=warn,
                                     insert_note="")
    l, r = rankserver.getCompFiles()
    return flask.render_template("index.html", urlroot=urlroot, intro=False,
                                 datadir=SHORT_RESDIR, err=False, done=False,
                                 msg="", rlist=rlist, l=l, r=r, warn=warn,
                                 insert_note="")

@bp.route("/intro", methods=["GET"])
@flask_login.login_required
def intro():
    global urlroot
    global SHORT_RESDIR
    return flask.render_template("index.html", urlroot=urlroot, intro=True, datadir=SHORT_RESDIR, err=False, done=False, msg="", rlist=[], l="", r="", warn="", insert_note="")

@bp.route("/api/rankables-info", methods=["GET"])
@flask_login.login_required
def rankables_info():
    is_link = os.path.islink(RES_DIR)
    realpath = os.path.realpath(RES_DIR)
    return flask.jsonify({
        'is_symlink': is_link,
        'symlink_path': RES_DIR,
        'real_path': realpath,
        'default_path': DEFAULT_TARGET
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

def _count_owned_links(stamp_dir):
    stamp_real = os.path.realpath(stamp_dir)
    count = 0
    for name in os.listdir(RES_DIR):
        full = os.path.join(RES_DIR, name)
        if os.path.islink(full):
            target = os.readlink(full)
            if not os.path.isabs(target):
                target = os.path.join(os.path.dirname(full), target)
            if os.path.realpath(os.path.dirname(target)) == stamp_real:
                count += 1
    return count


@bp.route("/api/watch-config", methods=["GET"])
@flask_login.login_required
def watch_config():
    cfg, err = load_config()
    watch = cfg.get("watch")
    linked = _count_owned_links(watch["stamp_dir"]) if watch else 0
    ins = cfg.get("insertions") or {}
    queue_len = len(ins.get("queue", [])) + (1 if ins.get("active") else 0)
    return flask.jsonify({"watch": watch, "linked_count": linked,
                          "queue_len": queue_len, "error": err})


@bp.route("/api/set-watch-config", methods=["POST"])
@flask_login.login_required
def set_watch_config():
    data = flask.request.get_json(silent=True) or {}
    # Guard the raw value: normpath("") is "." (the server CWD), which would
    # slip past an isdir check.
    raw_dir = data.get("stamp_dir") or ""
    tag = (data.get("stamp_tag") or "").strip()
    if not raw_dir:
        return flask.jsonify({"success": False, "error": "Missing stamp path"}), 400
    stamp_dir = os.path.normpath(raw_dir)
    if not os.path.isdir(stamp_dir):
        return flask.jsonify({"success": False, "error": "Stamp path is not a directory"}), 400
    if not tag:
        return flask.jsonify({"success": False, "error": "Missing stamp tag"}), 400
    cfg, _ = load_config()
    cfg["watch"] = {"stamp_dir": stamp_dir, "stamp_tag": tag}
    cfg.setdefault("insertions", {"queue": [], "active": None})
    save_config(cfg)
    warnings = sync_symlinks(cfg)
    return flask.jsonify({"success": True,
                          "linked_count": _count_owned_links(stamp_dir),
                          "warnings": warnings})


@bp.route("/api/clear-watch-config", methods=["POST"])
@flask_login.login_required
def clear_watch_config():
    cfg, _ = load_config()
    cfg.pop("watch", None)
    save_config(cfg)
    return flask.jsonify({"success": True})


@bp.route("/api/list-stamps", methods=["POST"])
@flask_login.login_required
def list_stamps():
    data = flask.request.get_json(silent=True) or {}
    raw_path = data.get("path") or ""
    if not raw_path:
        return flask.jsonify({"error": "Missing path"}), 400
    path = os.path.normpath(raw_path)
    try:
        return flask.jsonify({"tags": rankops.scan_stamps(os.listdir(path))})
    except PermissionError:
        return flask.jsonify({"error": "Permission denied"}), 403
    except (FileNotFoundError, NotADirectoryError):
        return flask.jsonify({"error": "Path not found"}), 404


@bp.route("/api/make-dir", methods=["POST"])
@flask_login.login_required
def make_dir():
    data = flask.request.get_json(silent=True) or {}
    path = data.get("path")
    name = (data.get("name") or "").strip()
    if (not path or not name or "/" in name or "\\" in name
            or "\x00" in name or name in (".", "..")):
        return flask.jsonify({"success": False, "error": "Invalid path or name"}), 400
    target = os.path.join(os.path.normpath(path), name)
    try:
        os.mkdir(target)
        return flask.jsonify({"success": True, "path": target})
    except OSError as e:
        return flask.jsonify({"success": False, "error": str(e)}), 500


@bp.route("/thumb/<path:filename>", methods=["GET"])
@flask_login.login_required
def thumb(filename):
    # Downscaled, disk-cached thumbnail served as PNG. For .png this is a Pillow
    # downscale; for .mp4 it is the first video frame extracted via ffmpeg. Both
    # cache to the same store so the ranked list can show many items (images or
    # video posters) as small lazy <img>s -- without downloading full-resolution
    # files or spinning up a per-item <video> decoder (which mobile browsers cap
    # in number). Cache key includes mtime and size so edits invalidate stale
    # thumbnails.
    safe = os.path.basename(filename)
    is_png = safe.lower().endswith(".png")
    is_mp4 = safe.lower().endswith(".mp4")
    if safe != filename or not (is_png or is_mp4):
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
        tmp = cached + ".tmp"
        if is_png:
            try:
                os.makedirs(THUMB_CACHE, exist_ok=True)
                img = Image.open(src)
                img.thumbnail((w, 100000000), Image.LANCZOS)
                img.save(tmp, format="PNG")
                os.replace(tmp, cached)
            except Exception:
                # Fall back to the original on any cache/decode/encode failure.
                return flask.send_file(src, mimetype="image/png", max_age=86400)
        else:
            # Extract a single frame near the start, scaled to width w. One decoded
            # frame, not the whole file. No usable fallback if this fails.
            try:
                os.makedirs(THUMB_CACHE, exist_ok=True)
                proc = subprocess.run(
                    ["ffmpeg", "-hide_banner", "-loglevel", "error",
                     "-i", src, "-frames:v", "1", "-vf", f"scale={w}:-1",
                     "-f", "image2", "-y", tmp],
                    capture_output=True,
                )
                ok = proc.returncode == 0 and os.path.exists(tmp)
            except Exception:
                ok = False
            if not ok:
                flask.abort(404)
            os.replace(tmp, cached)
    return flask.send_file(cached, mimetype="image/png", max_age=86400)

@bp.route("/media/<path:filename>", methods=["GET"])
@flask_login.login_required
def media(filename):
    # Serve a rankable video behind the same login gate as thumbnails. send_file
    # honours Range requests (conditional=True) so the browser can seek/stream
    # without downloading the whole file up front.
    safe = os.path.basename(filename)
    if safe != filename or not safe.lower().endswith(".mp4"):
        flask.abort(404)
    src = os.path.join(RES_DIR, safe)
    if not os.path.isfile(src):
        flask.abort(404)
    return flask.send_file(src, mimetype="video/mp4", max_age=86400, conditional=True)

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
