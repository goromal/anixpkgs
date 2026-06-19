import argparse
import os
import socket
import time
from email.mime.text import MIMEText
from email.utils import formatdate
from pathlib import Path

from flask import Flask, Blueprint, request, render_template

MAILDIR_PATH = "/var/mail/goromail"


def _write_to_maildir(text, maildir_path):
    new_dir = Path(maildir_path) / "new"
    new_dir.mkdir(parents=True, exist_ok=True)
    msg = MIMEText(text, "plain", "utf-8")
    msg["From"] = "andrew@localhost"
    msg["To"] = "goromail@localhost"
    msg["Subject"] = "Intake UI"
    msg["Date"] = formatdate()
    filename = f"{int(time.time())}.{os.getpid()}.{socket.gethostname()}"
    (new_dir / filename).write_bytes(msg.as_bytes())


def _load_categories(csv_path):
    categories = []
    try:
        with open(csv_path, "r") as f:
            for line in f:
                parts = line.strip().split(",", 1)
                if len(parts) == 2 and parts[0].strip():
                    categories.append(parts[0].strip())
    except FileNotFoundError:
        pass
    return categories


def create_app(subdomain="", maildir=None, categories_csv=None):
    _maildir = maildir or MAILDIR_PATH
    _categories_csv = os.path.expanduser(
        categories_csv or "~/configs/goromail-categories.csv"
    )

    app = Flask(__name__)
    bp = Blueprint("intake", __name__, url_prefix=subdomain)

    @bp.route("/", methods=["GET"])
    def index():
        categories = _load_categories(_categories_csv)
        return render_template("main.html", categories=categories, subdomain=subdomain)

    @bp.route("/submit", methods=["POST"])
    def submit():
        data = request.get_json(silent=True)
        if data is None:
            return {"error": "Invalid JSON"}, 400
        text = (data.get("text") or "").strip()
        if not text:
            return {"error": "text is required"}, 400
        try:
            _write_to_maildir(text, _maildir)
        except Exception as e:
            return {"error": str(e)}, 500
        return {"ok": True}

    @bp.route("/categories", methods=["GET"])
    def categories():
        return {"categories": _load_categories(_categories_csv)}

    app.register_blueprint(bp)
    return app


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=6161)
    parser.add_argument("--subdomain", type=str, default="/intake")
    parser.add_argument("--maildir", type=str, default=MAILDIR_PATH)
    parser.add_argument(
        "--categories-csv", type=str, default="~/configs/goromail-categories.csv"
    )
    args = parser.parse_args()

    app = create_app(
        subdomain=args.subdomain,
        maildir=args.maildir,
        categories_csv=args.categories_csv,
    )
    app.secret_key = os.urandom(24)
    app.run(host="0.0.0.0", port=args.port, debug=False)


if __name__ == "__main__":
    run()
