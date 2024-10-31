import sys
import os
import json

SETTINGS_FILE = sys.argv[1]

if os.path.exists(SETTINGS_FILE):
    with open(SETTINGS_FILE, "r") as original_file:
        settings = json.load(original_file)
else:
    settings = {}

if "clang-format.executable" not in settings:
    settings["clang-format.executable"] = "clang-format"

if "[cpp]" not in settings:
    settings["[cpp]"] = {
        "editor.defaultFormatter": "xaver.clang-format",
        "editor.formatOnSave": True
    }

with open(SETTINGS_FILE, "w") as new_file:
    new_file.write(json.dumps(settings))
