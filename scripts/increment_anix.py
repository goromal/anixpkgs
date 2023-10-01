import os
import sys

ANIXDIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANIXVERSFILE = os.path.join(ANIXDIR, "ANIX_VERSION")

def increment_version(idx):
    with open(ANIXVERSFILE, "r") as anixversfile:
        anixvers = anixversfile.read()
    anixvers_split = anixvers.split(".")
    anixvers_split[idx] = str(int(anixvers_split[idx]) + 1)
    with open(ANIXVERSFILE, "w") as anixversfile:
        anixversfile.write(".".join(anixvers_split))

version_field = sys.argv[1]
if version_field == "major":
    increment_version(0)
elif version_field == "minor":
    increment_version(1)
elif version_field == "patch":
    increment_version(2)
else:
    raise Exception(f"Unrecognized version field: {version_field}")
