import os
import re
import argparse
import flask
import flask_login
import flask_wtf
from wtforms import StringField, PasswordField, SubmitField
from werkzeug.security import generate_password_hash, check_password_hash
from random import shuffle
from datetime import timedelta

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--subdomain", action="store", type=str, default="/", help="Subdomain for a reverse proxy")
parser.add_argument("--data-dir", action="store", type=str, default="", help="Directory containing the stampable elements")
args = parser.parse_args()

urlroot = args.subdomain
if urlroot != "/":
    urlroot += "/"
url_for_prefix = args.subdomain.replace("/", "")
if len(url_for_prefix) > 0:
    url_for_prefix += "."

bp = flask.Blueprint("stamp", __name__, url_prefix=args.subdomain)

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
SHORT_RESDIR = os.path.basename(os.path.realpath(RES_DIR))

app = flask.Flask(__name__, static_url_path=args.subdomain, static_folder=RES_DIR)
app.secret_key = b"71d2dcdb895b367a1d5f0c66ca559c8d69af0c29a7e101c18c7c2d10399f264e"
app.config["PERMANENT_SESSION_LIFETIME"] = timedelta(minutes=20)
login_manager = flask_login.LoginManager()

class StampServer:
    STAMP = "asdfkl;ajsd;lkfj;ljkasdf"
    
    def __init__(self):
        self.reset()
        self.task_type = StampServer.STAMP

    def reset(self):
        self.filelist = []
        self.filedeck = ""

    def load(self):
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
        if self.task_type != StampServer.STAMP:
            self.reset()
            self.task_type = StampServer.STAMP
        if len(self.filelist) == 0:
            for file in os.listdir(RES_DIR):
                if file.startswith("stamped."):
                    continue
                if file.lower().endswith(".png"):
                    self.filelist.append((file.strip(), "PNG"))
                elif file.lower().endswith(".mp4"):
                    self.filelist.append((file.strip(), "MP4"))
            shuffle(self.filelist)
        if len(self.filelist) == 0:
            return (False, f"Data directory devoid of stampable files!")
        return (True, "")

    def load_stamped(self, stamp):
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
        if self.task_type != stamp:
            self.reset()
            self.task_type = stamp
        if len(self.filelist) == 0:
            for file in os.listdir(RES_DIR):
                if file.startswith(f"stamped.{stamp}"):
                    if file.lower().endswith(".png"):
                        self.filelist.append((file.strip(), "PNG"))
                    elif file.lower().endswith(".mp4"):
                        self.filelist.append((file.strip(), "MP4"))
            shuffle(self.filelist)
        if len(self.filelist) == 0:
            return (False, f"Data directory devoid of files stamped with {stamp}!")
        return (True, "")
    
    def getfile(self):
        for file, ftype in self.filelist:
            self.filedeck = file
            return file, ftype, len(self.filelist)
    
    def getstamps(self):
        stamps = {}
        for file in os.listdir(RES_DIR):
            stampmatch = re.search(r"stamped\.(.*?)\.", file)
            if stampmatch:
                if stampmatch.group(1) in stamps:
                    stamps[stampmatch.group(1)] += 1
                else:
                    stamps[stampmatch.group(1)] = 1
        return stamps

    def stamp(self, stamp):
        dirname = RES_DIR
        basename = os.path.basename(self.filedeck)
        os.rename(os.path.join(dirname, self.filedeck), os.path.join(dirname, f"stamped.{stamp}." + basename))
        self.filelist = list(filter(lambda t: t[0] != self.filedeck, self.filelist))

    def replace_stamp(self, stamp, new_stamp):
        dirname = RES_DIR
        basename = os.path.basename(self.filedeck)
        split_basename = basename.split(".")
        split_basename[1] = new_stamp
        new_basename = ".".join(split_basename)
        os.rename(os.path.join(dirname, self.filedeck), os.path.join(dirname, new_basename))
        self.filelist = list(filter(lambda t: t[0] != self.filedeck, self.filelist))

stampserver = StampServer()

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
    global urlroot
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
        return flask.render_template(
            "index.html",
            urlroot=urlroot,
            err=False,
            msg="",
            file="https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.mp4",
            ftype="MP4_EXT",
            root="zzz",
            nleft="?",
            datadir=SHORT_RESDIR,
            stamps={}
        )
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
    global stampserver
    global urlroot
    if flask.request.method == "POST":
        if flask.request.form["text"] != "":
            stampserver.stamp(flask.request.form["text"])
    res, msg = stampserver.load()
    stamps = stampserver.getstamps()
    if not res:
        return flask.render_template("index.html", urlroot=urlroot, err=True, msg=msg, file="", ftype="", root="", nleft="?", datadir=SHORT_RESDIR, stamps=stamps)
    file, ftype, numleft = stampserver.getfile()
    file = urlroot + file
    return flask.render_template("index.html", urlroot=urlroot, err=False, msg="", file=file, ftype=ftype, root="", nleft=str(numleft), datadir=SHORT_RESDIR, stamps=stamps)

@bp.route("/restamp/<stamp>", methods=["GET","POST"])
@flask_login.login_required
def stamped(stamp):
    global args
    global stampserver
    global urlroot
    if flask.request.method == "POST":
        if flask.request.form["text"] == "":
            new_stamp = stamp
        else:
            new_stamp = flask.request.form["text"]
        stampserver.replace_stamp(stamp, new_stamp)
    res, msg = stampserver.load_stamped(stamp)
    if not res:
        return flask.render_template("index.html", urlroot=urlroot, err=True, msg=msg, file="", ftype="", root=f"restamp/{stamp}", nleft="?", datadir=SHORT_RESDIR, stamps={})
    file, ftype, numleft = stampserver.getfile()
    file = urlroot + file
    return flask.render_template("index.html", urlroot=urlroot, err=False, msg="", file=file, ftype=ftype, root=f"restamp/{stamp}", nleft=str(numleft), datadir=SHORT_RESDIR, stamps={})

@bp.route("/zzz", methods=["GET","POST"])
@flask_login.login_required
def zzz():
    global urlroot
    return flask.render_template(
        "index.html",
        urlroot=urlroot,
        err=False,
        msg="",
        file="https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.mp4",
        ftype="MP4_EXT",
        root="zzz",
        nleft="?",
        datadir=SHORT_RESDIR,
        stamps={}
    )

@app.before_request
def refresh_session():
    flask.session.permanent = True
    flask.session.modified = True

def run():
    global args
    global url_for_prefix
    app.register_blueprint(bp)
    login_manager.init_app(app)
    login_manager.login_view = url_for_prefix + "login"
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
