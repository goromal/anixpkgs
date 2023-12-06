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
    def __init__(self):
        self.filelist = {}
        self.filedeck = ""

    def load(self):
        if not os.path.isdir(RES_DIR):
            return (False, f"Data directory non-existent or broken: {RES_DIR}")
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

stampserver = StampServer()

@app.route("/", methods=["GET","POST"])
def index():
    global args
    global stampserver
    if flask.request.method == "POST":
        stampserver.stamp(flask.request.form["text"])
    res, msg = stampserver.load()
    if not res:
        return flask.render_template("index.html", err=True, msg=msg, file="", ftype="")
    file, ftype = stampserver.getfile()
    return flask.render_template("index.html", err=False, msg="", file=file, ftype=ftype)

def run():
    global args
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
