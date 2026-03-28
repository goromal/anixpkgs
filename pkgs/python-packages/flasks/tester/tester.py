import os
import json
import argparse
import sqlite3
import random
import re
import difflib
from datetime import datetime
import flask

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5757, help="Port to run the server on")
parser.add_argument("--subdomain", action="store", type=str, default="/tester", help="Subdomain for a reverse proxy")
parser.add_argument("--db-path", action="store", type=str, default="", help="Path to SQLite database")
parser.add_argument("--data-dir", action="store", type=str, default="", help="Data directory for uploads and DB")
args = parser.parse_args()

urlroot = args.subdomain
if urlroot != "/":
    urlroot += "/"
url_for_prefix = args.subdomain.replace("/", "").replace("-", "_")
if len(url_for_prefix) > 0:
    url_for_prefix += "."

bp = flask.Blueprint("tester", __name__, url_prefix=args.subdomain)

PWD = os.getcwd()
DATA_DIR = args.data_dir if (args.data_dir and args.data_dir.startswith("/")) else os.path.join(PWD, args.data_dir or "tester_data")
DB_PATH = args.db_path if (args.db_path and args.db_path.startswith("/")) else os.path.join(DATA_DIR, "tester.db")

app = flask.Flask(__name__)
app.secret_key = b"tester_secret_key_change_in_production"


# ── Database ──────────────────────────────────────────────────────────────────

def get_db():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db


def init_db():
    os.makedirs(DATA_DIR, exist_ok=True)
    db = get_db()
    db.executescript("""
        CREATE TABLE IF NOT EXISTS exams (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            title           TEXT    NOT NULL,
            exam_type       TEXT    NOT NULL CHECK(exam_type IN ('rote','multiple_choice','short_answer')),
            created_at      TEXT    NOT NULL,
            source_material TEXT    NOT NULL DEFAULT '{}',
            content         TEXT    NOT NULL DEFAULT '{}'
        );
        CREATE TABLE IF NOT EXISTS results (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            exam_id  INTEGER NOT NULL,
            taken_at TEXT    NOT NULL,
            score    REAL    NOT NULL,
            details  TEXT    NOT NULL DEFAULT '[]',
            FOREIGN KEY (exam_id) REFERENCES exams (id)
        );
    """)
    db.commit()
    db.close()


init_db()


# ── Helpers ───────────────────────────────────────────────────────────────────

def now_str():
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")


def fuzzy_score(a, b):
    return difflib.SequenceMatcher(None, a.lower().strip(), b.lower().strip()).ratio()


def chunk_text(text, delimiter):
    if delimiter == "sentence":
        chunks = re.split(r"(?<=[.!?])\s+", text.strip())
    elif delimiter == "paragraph":
        chunks = [p.strip() for p in text.split("\n\n") if p.strip()]
    else:  # line
        chunks = [ln.strip() for ln in text.splitlines() if ln.strip()]
    return [c for c in chunks if c]


def fetch_url_content(url):
    import requests
    from bs4 import BeautifulSoup
    resp = requests.get(url, timeout=30)
    soup = BeautifulSoup(resp.text, "html.parser")
    for tag in soup(["script", "style", "nav", "footer", "header"]):
        tag.decompose()
    return soup.get_text(separator="\n", strip=True)[:20000]


def get_api_key():
    key_path = os.path.expanduser("~/secrets/claude/api_key.txt")
    with open(key_path) as f:
        return f.read().strip()


def call_claude(prompt):
    import anthropic
    client = anthropic.Anthropic(api_key=get_api_key())
    message = client.messages.create(
        model="claude-opus-4-6",
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def extract_json_array(text):
    match = re.search(r"\[.*\]", text, re.DOTALL)
    if not match:
        raise ValueError("No JSON array found in API response")
    return json.loads(match.group())


# ── Routes ────────────────────────────────────────────────────────────────────

@bp.route("/")
def index():
    db = get_db()
    exams = db.execute("SELECT * FROM exams ORDER BY created_at DESC").fetchall()
    exam_list = []
    for e in exams:
        last = db.execute(
            "SELECT score, taken_at FROM results WHERE exam_id = ? ORDER BY taken_at DESC LIMIT 1",
            (e["id"],),
        ).fetchone()
        exam_list.append({
            "id": e["id"],
            "title": e["title"],
            "exam_type": e["exam_type"],
            "created_at": e["created_at"],
            "last_score": round(last["score"] * 100) if last else None,
            "last_taken": last["taken_at"] if last else None,
        })
    db.close()
    return flask.render_template("index.html", urlroot=urlroot, exams=exam_list)


@bp.route("/create", methods=["GET", "POST"])
def create():
    if flask.request.method == "GET":
        return flask.render_template("create.html", urlroot=urlroot)

    exam_type = flask.request.form.get("exam_type", "")
    title = flask.request.form.get("title", "").strip()

    if not title:
        flask.flash("Title is required.")
        return flask.redirect(flask.url_for(url_for_prefix + "create"))

    if exam_type == "rote":
        return _create_rote(title)
    elif exam_type in ("multiple_choice", "short_answer"):
        return _create_ai_exam(title, exam_type)
    else:
        flask.flash("Invalid exam type.")
        return flask.redirect(flask.url_for(url_for_prefix + "create"))


def _create_rote(title):
    text = flask.request.form.get("text", "").strip()

    if not text:
        flask.flash("Text is required for rote memorization exams.")
        return flask.redirect(flask.url_for(url_for_prefix + "create"))

    # Split into atomic units: prefer lines, fall back to sentences if newlines were lost.
    atoms = chunk_text(text, "line")
    if len(atoms) < 2:
        atoms = chunk_text(text, "sentence")
    if len(atoms) < 2:
        flask.flash("Could not split text into at least 2 units. Try adding newlines between sections.")
        return flask.redirect(flask.url_for(url_for_prefix + "create"))

    content = json.dumps({"full_text": text, "atoms": atoms})
    db = get_db()
    db.execute(
        "INSERT INTO exams (title, exam_type, created_at, source_material, content) VALUES (?,?,?,?,?)",
        (title, "rote", now_str(), "{}", content),
    )
    db.commit()
    db.close()
    flask.flash(f"Rote exam created with {len(atoms)} units.")
    return flask.redirect(flask.url_for(url_for_prefix + "index"))


def _create_ai_exam(title, exam_type):
    urls = [u.strip() for u in flask.request.form.get("urls", "").splitlines() if u.strip()]
    emphasis = flask.request.form.get("emphasis", "").strip()
    try:
        num_q = max(1, min(30, int(flask.request.form.get("num_questions", "10"))))
    except ValueError:
        num_q = 10

    source_texts = []
    for url in urls:
        try:
            source_texts.append(f"[Source: {url}]\n{fetch_url_content(url)}")
        except Exception as exc:
            flask.flash(f"Could not fetch {url}: {exc}")

    for f in flask.request.files.getlist("files"):
        if f and f.filename:
            try:
                source_texts.append(f"[File: {f.filename}]\n{f.read().decode('utf-8', errors='replace')[:20000]}")
            except Exception as exc:
                flask.flash(f"Could not read {f.filename}: {exc}")

    pasted = flask.request.form.get("pasted_text", "").strip()
    if pasted:
        source_texts.append(f"[Pasted text]\n{pasted[:20000]}")

    topics = [t.strip() for t in flask.request.form.get("topics", "").splitlines() if t.strip()]

    if not source_texts and not topics:
        flask.flash("No source material provided (URLs, files, pasted text, or topics required).")
        return flask.redirect(flask.url_for(url_for_prefix + "create"))

    combined = "\n\n".join(source_texts)[:40000]
    emphasis_block = f"\n\nPoints of emphasis:\n{emphasis}" if emphasis else ""

    if topics:
        topics_block = "Topics to draw on from your own knowledge:\n" + "\n".join(f"- {t}" for t in topics)
    else:
        topics_block = ""

    if source_texts and topics:
        material_section = f"Source material:\n{combined}\n\n{topics_block}"
    elif source_texts:
        material_section = f"Source material:\n{combined}"
    else:
        material_section = topics_block

    if exam_type == "multiple_choice":
        prompt = (
            f"You are a quiz master. Create exactly {num_q} multiple choice questions based on the following. "
            f"For topic-based questions, draw on your own knowledge.\n\n{material_section}{emphasis_block}\n\n"
            f"Return ONLY a valid JSON array, no other text:\n"
            f'[{{"question":"...","options":["a","b","c","d"],"correct":0}}]\n\n'
            f'"correct" is the 0-based index of the correct option.'
        )
    else:  # short_answer
        prompt = (
            f"You are a quiz master. Create exactly {num_q} short answer questions based on the following. "
            f"For topic-based questions, draw on your own knowledge.\n\n{material_section}{emphasis_block}\n\n"
            f'Return ONLY a valid JSON array of question strings, no other text:\n["question 1","question 2",...]'
        )

    try:
        response = call_claude(prompt)
        questions = extract_json_array(response)
    except Exception as exc:
        flask.flash(f"Error generating exam via AI: {exc}")
        return flask.redirect(flask.url_for(url_for_prefix + "create"))

    source_material = json.dumps({"urls": urls, "emphasis": emphasis})
    content = json.dumps({"questions": questions})

    db = get_db()
    db.execute(
        "INSERT INTO exams (title, exam_type, created_at, source_material, content) VALUES (?,?,?,?,?)",
        (title, exam_type, now_str(), source_material, content),
    )
    db.commit()
    db.close()
    flask.flash(f"Exam created with {len(questions)} questions.")
    return flask.redirect(flask.url_for(url_for_prefix + "index"))


@bp.route("/exam/<int:exam_id>/delete", methods=["POST"])
def delete_exam(exam_id):
    db = get_db()
    db.execute("DELETE FROM results WHERE exam_id = ?", (exam_id,))
    db.execute("DELETE FROM exams WHERE id = ?", (exam_id,))
    db.commit()
    db.close()
    flask.flash("Exam deleted.")
    return flask.redirect(flask.url_for(url_for_prefix + "index"))


@bp.route("/exam/<int:exam_id>/take")
def take_exam(exam_id):
    db = get_db()
    exam = db.execute("SELECT * FROM exams WHERE id = ?", (exam_id,)).fetchone()
    db.close()
    if not exam:
        flask.flash("Exam not found.")
        return flask.redirect(flask.url_for(url_for_prefix + "index"))

    exam = dict(exam)
    content = json.loads(exam["content"])

    if exam["exam_type"] == "rote":
        atoms = content.get("atoms") or content.get("chunks", [])
        return flask.render_template(
            "take_rote.html",
            urlroot=urlroot,
            exam=exam,
            atoms_json=json.dumps(atoms),
            atom_count=len(atoms),
        )
    elif exam["exam_type"] == "multiple_choice":
        return flask.render_template(
            "take_mc.html",
            urlroot=urlroot,
            exam=exam,
            questions=content["questions"],
        )
    else:  # short_answer
        return flask.render_template(
            "take_sa.html",
            urlroot=urlroot,
            exam=exam,
            questions=content["questions"],
        )


@bp.route("/exam/<int:exam_id>/passage")
def view_passage(exam_id):
    db = get_db()
    exam = db.execute("SELECT * FROM exams WHERE id = ?", (exam_id,)).fetchone()
    db.close()
    if not exam:
        flask.flash("Exam not found.")
        return flask.redirect(flask.url_for(url_for_prefix + "index"))
    exam = dict(exam)
    content = json.loads(exam["content"])
    atoms = content.get("atoms") or content.get("chunks", [])
    return flask.render_template(
        "passage.html",
        urlroot=urlroot,
        exam=exam,
        atoms=atoms,
    )


@bp.route("/exam/<int:exam_id>/submit", methods=["POST"])
def submit_exam(exam_id):
    db = get_db()
    exam = db.execute("SELECT * FROM exams WHERE id = ?", (exam_id,)).fetchone()
    db.close()
    if not exam:
        flask.flash("Exam not found.")
        return flask.redirect(flask.url_for(url_for_prefix + "index"))

    exam = dict(exam)
    content = json.loads(exam["content"])

    if exam["exam_type"] == "rote":
        result_id = _grade_rote(exam_id, content)
    elif exam["exam_type"] == "multiple_choice":
        result_id = _grade_mc(exam_id, content)
    else:
        result_id = _grade_sa(exam_id, content)

    if result_id is None:
        return flask.redirect(flask.url_for(url_for_prefix + "take_exam", exam_id=exam_id))

    return flask.redirect(flask.url_for(url_for_prefix + "result", result_id=result_id))


def _grade_rote(exam_id, content):
    atoms = content.get("atoms") or content.get("chunks", [])
    chunk_size = max(1, int(flask.request.form.get("chunk_size", "1")))
    # Re-derive chunks the same way the client did
    chunks = [" ".join(atoms[i:i + chunk_size]) for i in range(0, len(atoms), chunk_size)]
    blank_indices = json.loads(flask.request.form.get("blank_indices", "[]"))
    THRESHOLD = 0.80

    details = []
    correct_count = 0
    for i, idx in enumerate(blank_indices):
        actual = chunks[idx]
        user_answer = flask.request.form.get(f"answer_{i}", "").strip()
        score = fuzzy_score(actual, user_answer)
        is_correct = score >= THRESHOLD
        if is_correct:
            correct_count += 1
        details.append({
            "chunk_index": idx,
            "chunk": actual,
            "user_answer": user_answer,
            "score": round(score, 3),
            "correct": is_correct,
        })

    overall = correct_count / len(blank_indices) if blank_indices else 0.0
    db = get_db()
    cur = db.execute(
        "INSERT INTO results (exam_id, taken_at, score, details) VALUES (?,?,?,?)",
        (exam_id, now_str(), overall, json.dumps(details)),
    )
    result_id = cur.lastrowid
    db.commit()
    db.close()
    return result_id


def _grade_mc(exam_id, content):
    questions = content["questions"]
    details = []
    correct_count = 0
    for i, q in enumerate(questions):
        raw = flask.request.form.get(f"answer_{i}")
        user_idx = int(raw) if raw is not None else -1
        is_correct = user_idx == q["correct"]
        if is_correct:
            correct_count += 1
        details.append({
            "question": q["question"],
            "options": q["options"],
            "correct": q["correct"],
            "user_answer": user_idx,
            "is_correct": is_correct,
        })

    overall = correct_count / len(questions) if questions else 0.0
    db = get_db()
    cur = db.execute(
        "INSERT INTO results (exam_id, taken_at, score, details) VALUES (?,?,?,?)",
        (exam_id, now_str(), overall, json.dumps(details)),
    )
    result_id = cur.lastrowid
    db.commit()
    db.close()
    return result_id


def _grade_sa(exam_id, content):
    questions = content["questions"]
    answers = [flask.request.form.get(f"answer_{i}", "").strip() for i in range(len(questions))]

    qa_text = "\n".join(
        f"Q{i+1}: {q}\nA{i+1}: {a}" for i, (q, a) in enumerate(zip(questions, answers))
    )
    prompt = (
        f"You are a teacher grading a short answer exam. Grade each student answer.\n\n"
        f"Questions and student answers:\n{qa_text}\n\n"
        f"Return ONLY a valid JSON array, no other text:\n"
        f'[{{"question":"...","user_answer":"...","score":0.8,"justification":"..."}}]\n\n'
        f'"score" is a float 0.0–1.0. Be fair but accurate.'
    )

    try:
        response = call_claude(prompt)
        details = extract_json_array(response)
        overall = sum(d.get("score", 0) for d in details) / len(details) if details else 0.0
    except Exception as exc:
        flask.flash(f"Error grading exam via AI: {exc}")
        return None

    db = get_db()
    cur = db.execute(
        "INSERT INTO results (exam_id, taken_at, score, details) VALUES (?,?,?,?)",
        (exam_id, now_str(), overall, json.dumps(details)),
    )
    result_id = cur.lastrowid
    db.commit()
    db.close()
    return result_id


@bp.route("/exam/<int:exam_id>/results")
def exam_results(exam_id):
    db = get_db()
    exam = db.execute("SELECT * FROM exams WHERE id = ?", (exam_id,)).fetchone()
    if not exam:
        db.close()
        flask.flash("Exam not found.")
        return flask.redirect(flask.url_for(url_for_prefix + "index"))
    results = db.execute(
        "SELECT id, taken_at, score FROM results WHERE exam_id = ? ORDER BY taken_at DESC",
        (exam_id,),
    ).fetchall()
    db.close()
    return flask.render_template(
        "results.html",
        urlroot=urlroot,
        exam=dict(exam),
        results=[dict(r) for r in results],
    )


@bp.route("/result/<int:result_id>")
def result(result_id):
    db = get_db()
    res = db.execute("SELECT * FROM results WHERE id = ?", (result_id,)).fetchone()
    if not res:
        db.close()
        flask.flash("Result not found.")
        return flask.redirect(flask.url_for(url_for_prefix + "index"))
    res = dict(res)
    exam = dict(db.execute("SELECT * FROM exams WHERE id = ?", (res["exam_id"],)).fetchone())
    db.close()
    details = json.loads(res["details"])
    return flask.render_template(
        "result.html",
        urlroot=urlroot,
        exam=exam,
        result=res,
        details=details,
        score_pct=round(res["score"] * 100),
    )


def run():
    global args
    app.register_blueprint(bp)
    app.run(host="0.0.0.0", port=args.port)


if __name__ == "__main__":
    run()
