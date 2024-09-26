import sys
import os
import json

SETTINGS_FILE = sys.argv[1]
VAR_NAME = sys.argv[2]
VAR_VAL = sys.argv[3]

if os.path.exists(SETTINGS_FILE):
    with open(SETTINGS_FILE, "r") as original_file:
        settings = json.load(original_file)
else:
    settings = {}

if "editor.semanticTokenColorCustomizations" not in settings:
    settings["editor.semanticTokenColorCustomizations"] = {
        "rules": {
            "*.mutable": {
                "fontStyle": "underline",
            },
            "operator.unsafe": "#ff6600",
            "function.unsafe": "#ff6600",
            "method.unsafe": "#ff6600",
        }
    }

if "rust-analyzer.server.extraEnv" not in settings:
    settings["rust-analyzer.server.extraEnv"] = {}

settings["rust-analyzer.server.extraEnv"][VAR_NAME] = VAR_VAL

with open(SETTINGS_FILE, "w") as new_file:
    new_file.write(json.dumps(settings))
