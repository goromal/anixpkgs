import os
import argparse
import flask

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--data-dir", action="store", type=str, default="", help="Directory containing the stampable elements")
args = parser.parse_args()

PWD = os.getcwd()
if args.data_dir[0] == '/':
    RES_DIR = args.data_dir
else:
    RES_DIR = os.path.join(PWD, args.data_dir)

app = flask.Flask(__name__, static_url_path="", static_folder=RES_DIR)

class StampServer:
    STAMP = 0
    RESTAMP = 1
    
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
        if self.task_type != StampServer.RESTAMP:
            self.reset()
            self.task_type = StampServer.RESTAMP
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
            return file, ftype

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

@app.route("/", methods=["GET","POST"])
def index():
    global args
    global stampserver
    if flask.request.method == "POST":
        if flask.request.form["text"] != "":
            stampserver.stamp(flask.request.form["text"])
    res, msg = stampserver.load()
    if not res:
        return flask.render_template("index.html", err=True, msg=msg, file="", ftype="", root="")
    file, ftype = stampserver.getfile()
    return flask.render_template("index.html", err=False, msg="", file=file, ftype=ftype, root="")

@app.route("/restamp/<stamp>", methods=["GET","POST"])
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
        return flask.render_template("index.html", err=True, msg=msg, file="", ftype="", root=f"restamp/{stamp}")
    file, ftype = stampserver.getfile()
    return flask.render_template("index.html", err=False, msg="", file=file, ftype=ftype, root=f"restamp/{stamp}")

def run():
    global args
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
