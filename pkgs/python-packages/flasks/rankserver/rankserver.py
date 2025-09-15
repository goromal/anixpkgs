import os
import argparse
import flask
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
args = parser.parse_args()

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
    _user = None
    def check_password(self, password):
        return check_password_hash("scrypt:32768:8:1$acPu0meyxPfx0SnS$26a570af250e0593c2dbb6bfb1d037a7366109a0ba4886e68191237efdabb2fca07de6c81c337b5e275390c2d7ff96f3455f47b7a05027a7e0ebf1628f537498", password)
    def get_id(self):
        return self._user

user = User()

PWD = os.getcwd()
if args.data_dir[0] == '/':
    RES_DIR = args.data_dir
else:
    RES_DIR = os.path.join(PWD, args.data_dir)

app = flask.Flask(__name__, static_url_path=args.subdomain, static_folder=RES_DIR)
app.secret_key = b"71d2dcdb895b367a1d5f0c66ca559c8d69af0c29a7e101c18c7c2d10399f264e"
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
        if form.username.data != form.password.data or not user.check_password(form.password.data):
            return flask.redirect(flask.url_for(url_for_prefix + "login"))
        flask_login.login_user(user, remember=False)
        flask.session.permanent = True
        next = flask.request.args.get('next')
        return flask.redirect(next or flask.url_for(url_for_prefix + 'index'))
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
        return flask.render_template("index.html", urlroot=urlroot, err=True, done=False, msg=msg, rlist=[], l="", n="")
    rlist = rankserver.getRankList()
    if rankserver.sortingComplete():
        return flask.render_template("index.html", urlroot=urlroot, err=False, done=True, msg="", rlist=rlist, l="", n="")
    else:
        l, r = rankserver.getCompFiles()
        return flask.render_template("index.html", urlroot=urlroot, err=False, done=False, msg="", rlist=rlist, l=l, r=r)

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
