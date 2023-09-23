import json
import os
import sys

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(os.path.join(ANIXDIR, "index.json"), "r") as idxfile:
    pkgs = json.loads(idxfile.read())

if len(sys.argv) > 1 and (sys.argv[1] == "misc" or sys.argv[1] == "cpp" or sys.argv[1] == "python"):
    attrlist = [pkg["attr"] for pkg in pkgs["pkgs"][sys.argv[1]] if pkg["ci"]]
    for attr in attrlist:
        print(attr)
else:
    print("ERROR: must give one of [misc, cpp, python] as an input")
