import os
import re
import argparse
import flask
import flask_login
import flask_wtf
from wtforms import StringField, PasswordField, SubmitField
from werkzeug.security import generate_password_hash, check_password_hash

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--data-dir", action="store", type=str, default="", help="Directory containing the stampable elements")
args = parser.parse_args()

class LoginForm(flask_wtf.FlaskForm):
    username = StringField("Username")
    password = PasswordField("Password")
    submit = SubmitField("Submit")

class User(flask_login.UserMixin):
    def check_password(self, password):
        return check_password_hash("pbkdf2:sha256:260000$lZSRuIMsXegmiXNl$8a1fde09226a09391218ec3b1f07f6d8373a055f0469b69d0855f9cc29a53e31", password)
    def get_id(self):
        return "anonymous"

user = User()

PWD = os.getcwd()
if args.data_dir[0] == '/':
    RES_DIR = args.data_dir
else:
    RES_DIR = os.path.join(PWD, args.data_dir)
SHORT_RESDIR = os.path.basename(os.path.realpath(RES_DIR))

app = flask.Flask(__name__, static_url_path="", static_folder=RES_DIR)
app.secret_key = b"71d2dcdb895b367a1d5f0c66ca559c8d69af0c29a7e101c18c7c2d10399f264e"
login_manager = flask_login.LoginManager()

class StampServer:
    STAMP = "asdfkl;ajsd;lkfj;ljkasdf"
    
    def __init__(self):
        self.reset()
        self.task_type = StampServer.STAMP

    def reset(self):
        self.filelist = {}
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
                    self.filelist[file.strip()] = "PNG"
                elif file.lower().endswith(".mp4"):
                    self.filelist[file.strip()] = "MP4"
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
                        self.filelist[file.strip()] = "PNG"
                    elif file.lower().endswith(".mp4"):
                        self.filelist[file.strip()] = "MP4"
        if len(self.filelist) == 0:
            return (False, f"Data directory devoid of files stamped with {stamp}!")
        return (True, "")
    
    def getfile(self):
        for file, ftype in self.filelist.items():
            self.filedeck = file
            return file, ftype, len(self.filelist.keys())
    
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
        try:
            dirname = os.path.dirname(self.filedeck)
            basename = os.path.basename(self.filedeck)
            os.rename(self.filedeck, os.path.join(dirname, f"stamped.{stamp}." + basename))
            self.filelist.pop(self.filedeck, None)
        except:
            pass

    def replace_stamp(self, stamp, new_stamp):
        try:
            dirname = os.path.dirname(self.filedeck)
            basename = os.path.basename(self.filedeck)
            split_basename = basename.split(".")
            split_basename[1] = new_stamp
            new_basename = ".".join(split_basename)
            os.rename(self.filedeck, os.path.join(dirname, new_basename))
            self.filelist.pop(self.filedeck, None)
        except:
            pass

stampserver = StampServer()

@login_manager.user_loader
def load_user(user_id):
    global user
    if user_id == "anonymous":
        return user
    else:
        return None
      
@app.route("/login", methods=["GET", "POST"])
def login():
    global user
    if flask_login.current_user.is_authenticated:
        return flask.redirect(flask.url_for('index'))
    form = LoginForm()
    if form.validate_on_submit():
        if form.username.data != user.get_id() or not user.check_password(form.password.data):
            return flask.redirect(flask.url_for("login"))
        flask_login.login_user(user, remember=True)
        next = flask.request.args.get('next')
        # if not url_has_allowed_host_and_scheme(next, flask.request.host):
        #     return flask.abort(400)
        return flask.redirect(next or flask.url_for('index'))
    return flask.render_template("login.html", title="Sign In", form=form)
      
@app.route("/logout")
@flask_login.login_required
def logout():
    flask_login.logout_user()
    return flask.redirect(flask.url_for("login"))

@app.route("/", methods=["GET","POST"])
@flask_login.login_required
def index():
    global args
    global stampserver
    if flask.request.method == "POST":
        if flask.request.form["text"] != "":
            stampserver.stamp(flask.request.form["text"])
    res, msg = stampserver.load()
    stamps = stampserver.getstamps()
    if not res:
        return flask.render_template("index.html", err=True, msg=msg, file="", ftype="", root="", nleft="?", datadir=SHORT_RESDIR, stamps=stamps)
    file, ftype, numleft = stampserver.getfile()
    return flask.render_template("index.html", err=False, msg="", file=file, ftype=ftype, root="", nleft=str(numleft), datadir=SHORT_RESDIR, stamps=stamps)

@app.route("/restamp/<stamp>", methods=["GET","POST"])
@flask_login.login_required
def stamped(stamp):
    global args
    global stampserver
    if flask.request.method == "POST":
        if flask.request.form["text"] == "":
            new_stamp = stamp
        else:
            new_stamp = flask.request.form["text"]
        stampserver.replace_stamp(stamp, new_stamp)
    res, msg = stampserver.load_stamped(stamp)
    if not res:
        return flask.render_template("index.html", err=True, msg=msg, file="", ftype="", root=f"restamp/{stamp}", nleft="?", datadir=SHORT_RESDIR, stamps={})
    file, ftype, numleft = stampserver.getfile()
    return flask.render_template("index.html", err=False, msg="", file=file, ftype=ftype, root=f"restamp/{stamp}", nleft=str(numleft), datadir=SHORT_RESDIR, stamps={})

@app.route("/zzz", methods=["GET","POST"])
@flask_login.login_required
def zzz():
    return flask.render_template(
        "index.html",
        err=False,
        msg="",
        file="https://github.com/goromal/anixdata/raw/master/data/media/scrape-tests/sample_640x360.mp4",
        ftype="MP4_EXT",
        root="zzz"
    )

def run():
    global args
    login_manager.init_app(app)
    login_manager.login_view = "login"
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
