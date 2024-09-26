import sys

SETTINGS_FILE = sys.argv[1]
VAR_NAME = sys.argv[2]
VAR_VAL = sys.argv[3]

print(f"{SETTINGS_FILE} <- {VAR_NAME}: {VAR_VAL}")
