import os
import argparse
import flask
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
parser.add_argument("--data-dir", action="store", type=str, default="", help="Directory containing the rankable elements")
args = parser.parse_args()

PWD = os.getcwd()
RES_DIR = os.path.join(PWD, args.data_dir)

app = flask.Flask(__name__, static_url_path="", static_folder=RES_DIR)

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
        self.rev_rank_list = []
        for i in range(self.state.n):
            self.rev_rank_list.append(self.rank_list[-i])
        print(self.rev_rank_list)
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
        print(f"arr={self.state.arr}")
        print(f"p={self.state.p} i={self.state.i} j={self.state.j}")
        rightfile = self.rank_list[self.state.arr[self.state.p]]
        if self.state.l == int(ComparatorLeft.I):
            leftfile = self.rank_list[self.state.arr[self.state.i]]
        else:
            leftfile = self.rank_list[self.state.arr[self.state.j]]
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

@app.route("/", methods=["GET","POST"])
def index():
    global args
    global rankserver
    if flask.request.method == "POST":
        if rankserver.sortingComplete():
            rankserver.resetState()
        else:
            if "choose_l" in flask.request.form:
                # print("CHOOSE LEFT")
                rankserver.submitChoice(int(ComparatorResult.LEFT_GREATER))
            else:
                # print("CHOOSE_RIGHT")
                rankserver.submitChoice(int(ComparatorResult.LEFT_LESS))
        rankserver.save()
    
    res, msg = rankserver.load()
    if not res:
        return flask.render_template("index.html", err=True, done=False, msg=msg, rlist=[], l="", n="")
    rlist = rankserver.getRankList()
    if rankserver.sortingComplete():
        return flask.render_template("index.html", err=False, done=True, msg="", rlist=rlist, l="", n="")
    else:
        l, r = rankserver.getCompFiles()
        return flask.render_template("index.html", err=False, done=False, msg="", rlist=rlist, l=l, r=r)

def run():
    global args
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
