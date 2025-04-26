from flask import Flask, render_template, request, redirect, url_for, flash
from easy_google_auth.auth import HeadlessCredentialsGenerator
from gmail_parser.defaults import GmailParserDefaults as GPD
import os
import json
import argparse
from datetime import datetime

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--memory-file", action="store", type=str, default="refresh_times.json", help="Path to persistent memory file")
args = parser.parse_args()

refresh_times = {}

app = Flask(__name__)
app.secret_key = os.urandom(24)

GENERATOR_CONFIGS = {
    "user": {
        "name": "User",
        "secrets_file": GPD.getKwargsOrDefault("gmail_secrets_json"),
        "refresh_token": GPD.getKwargsOrDefault("gmail_refresh_file"),
    },
    "bot": {
        "name": "Bot",
        "secrets_file": GPD.getKwargsOrDefault("gmail_secrets_json"),
        "refresh_token": GPD.getKwargsOrDefault("gbot_refresh_file"),
    },
    "journal": {
        "name": "Journal",
        "secrets_file": GPD.getKwargsOrDefault("gmail_secrets_json"),
        "refresh_token": GPD.getKwargsOrDefault("journal_refresh_file"),
    },
}

generators = {}
generators_initialized = False

def load_refresh_times():
    if os.path.exists(args.memory_file):
        with open(args.memory_file, "r") as f:
            return json.load(f)
    return {}

def save_refresh_times():
    with open(args.memory_file, "w") as f:
        json.dump(refresh_times, f, indent=2)

refresh_times = load_refresh_times()

@app.route("/", methods=["GET", "POST"])
def index():
    global generators_initialized

    if request.method == "POST" and not generators_initialized:
        for key, cfg in GENERATOR_CONFIGS.items():
            generators[key] = HeadlessCredentialsGenerator(
                secrets_file=cfg["secrets_file"],
                refresh_token=cfg["refresh_token"]
            )
        generators_initialized = True
        flash("Generators initialized!")

    return render_template("index.html",
                       generators=generators,
                       generator_configs=GENERATOR_CONFIGS,
                       initialized=generators_initialized,
                       refresh_times=refresh_times)


@app.route("/submit/<gen_key>", methods=["POST"])
def submit(gen_key):
    auth_code = request.form.get("auth_code")
    if gen_key in generators and auth_code:
        try:
            generators[gen_key].authorize(auth_code)
            refresh_times[gen_key] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            save_refresh_times()
            flash(f"{GENERATOR_CONFIGS[gen_key]['name']} credentials saved.")
        except Exception as e:
            flash(f"Error authorizing {GENERATOR_CONFIGS[gen_key]['name']}: {e}")
    return redirect(url_for("index"))


@app.route("/reset", methods=["POST"])
def reset():
    global generators_initialized
    generators.clear()
    generators_initialized = False
    refresh_times.clear()
    save_refresh_times()
    flash("Setup reset.")
    return redirect(url_for("index"))

def run():
    global args
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
