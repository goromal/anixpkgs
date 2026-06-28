import os
import time
import sqlite3
import argparse
import datetime

import flask
import requests

DB_PATH = None

BOOKS = [
    ("1 Nephi", 22), ("2 Nephi", 33), ("Jacob", 7), ("Enos", 1),
    ("Jarom", 1), ("Omni", 1), ("Words of Mormon", 1), ("Mosiah", 29),
    ("Alma", 63), ("Helaman", 16), ("3 Nephi", 30), ("4 Nephi", 1),
    ("Mormon", 9), ("Ether", 15), ("Moroni", 10),
]

CHRIST_NAMES = [
    "jesus christ", "jesus", "christ", "messiah", "savior", "saviour",
    "redeemer", "lamb of god", "son of god", "son of the living god",
    "holy one of israel", "lord god", "eternal father", "emmanuel",
    "only begotten", "beloved son", "son of man", "prince of peace",
    "lord omnipotent", "keeper of the gate", "great jehovah",
]

API_URL = "https://api.nephi.org/scriptures/"


def get_db():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    return db


def init_db():
    db = get_db()
    db.executescript("""
        CREATE TABLE IF NOT EXISTS books (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT NOT NULL,
            order_index INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS verses (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id       INTEGER NOT NULL REFERENCES books(id),
            chapter       INTEGER NOT NULL,
            verse_num     INTEGER NOT NULL,
            text          TEXT NOT NULL,
            scripture_ref TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS verse_groups (
            id                  INTEGER PRIMARY KEY AUTOINCREMENT,
            is_christ_group     BOOLEAN NOT NULL DEFAULT 0,
            manually_overridden BOOLEAN NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS verse_group_members (
            group_id INTEGER NOT NULL REFERENCES verse_groups(id),
            verse_id INTEGER NOT NULL REFERENCES verses(id),
            role     TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS tags (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL UNIQUE,
            created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS group_tags (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL REFERENCES verse_groups(id),
            tag_id   INTEGER NOT NULL REFERENCES tags(id),
            UNIQUE(group_id, tag_id)
        );
        CREATE TABLE IF NOT EXISTS group_notes (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id   INTEGER NOT NULL UNIQUE REFERENCES verse_groups(id),
            note       TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS group_processed (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id     INTEGER NOT NULL UNIQUE REFERENCES verse_groups(id),
            processed_at TEXT NOT NULL
        );
    """)
    db.commit()
    db.close()


def _has_christ_ref(text):
    lower = text.lower()
    return any(name in lower for name in CHRIST_NAMES)


def _build_groups(verse_rows):
    """verse_rows: list of (verse_id, verse_num, text) sorted by verse_num.
    Returns list of member lists; each member is (verse_id, verse_num, role)."""
    marked = [(vid, vnum, txt, _has_christ_ref(txt)) for vid, vnum, txt in verse_rows]
    groups = []
    i = 0
    while i < len(marked):
        if not marked[i][3]:
            i += 1
            continue
        run_start = i
        while i < len(marked) and marked[i][3]:
            i += 1
        run = marked[run_start:i]
        members = []
        if run_start > 0:
            prev = marked[run_start - 1]
            members.append((prev[0], prev[1], "context_before"))
        for vid, vnum, _, _ in run:
            members.append((vid, vnum, "christ_ref"))
        if i < len(marked):
            nxt = marked[i]
            members.append((nxt[0], nxt[1], "context_after"))
        groups.append(members)
    return groups


def do_ingest(db_path, force=False):
    global DB_PATH
    DB_PATH = db_path
    init_db()
    db = get_db()
    count = db.execute("SELECT COUNT(*) FROM verses").fetchone()[0]
    if count > 0 and not force:
        print(f"DB already has {count} verses. Use --force to repopulate.")
        db.close()
        return
    if force and count > 0:
        print("Wiping existing data...")
        db.executescript("""
            DELETE FROM group_processed; DELETE FROM group_tags;
            DELETE FROM group_notes; DELETE FROM verse_group_members;
            DELETE FROM verse_groups; DELETE FROM verses; DELETE FROM books;
        """)
        db.commit()

    for order_idx, (book_name, num_chapters) in enumerate(BOOKS):
        db.execute("INSERT INTO books (name, order_index) VALUES (?, ?)", (book_name, order_idx))
        db.commit()
        book_id = db.execute("SELECT id FROM books WHERE name=?", (book_name,)).fetchone()[0]
        print(f"  {book_name} ({num_chapters} chapters)...")
        for chapter in range(1, num_chapters + 1):
            resp = None
            for attempt in range(3):
                try:
                    resp = requests.get(API_URL, params={"q": f"{book_name} {chapter}:1-200"}, timeout=15)
                    if resp.status_code < 500:
                        break
                    print(f"    API error {resp.status_code} on {book_name} {chapter}, retry {attempt+1}/3...")
                except requests.exceptions.RequestException:
                    pass
                time.sleep(2)
            if resp is None or resp.status_code >= 500:
                print(f"    Skipping {book_name} {chapter} after repeated 5xx errors.")
                continue
            resp.raise_for_status()
            api_verses = resp.json().get("scriptures", [])
            verse_rows = []
            for v in api_verses:
                ref = f"{book_name} {chapter}:{v['verse']}"
                cur = db.execute(
                    "INSERT INTO verses (book_id, chapter, verse_num, text, scripture_ref)"
                    " VALUES (?,?,?,?,?)",
                    (book_id, chapter, v["verse"], v["text"], ref),
                )
                verse_rows.append((cur.lastrowid, v["verse"], v["text"]))
            db.commit()
            for members in _build_groups(verse_rows):
                cur = db.execute(
                    "INSERT INTO verse_groups (is_christ_group, manually_overridden) VALUES (1, 0)"
                )
                gid = cur.lastrowid
                for vid, _, role in members:
                    db.execute(
                        "INSERT INTO verse_group_members (group_id, verse_id, role) VALUES (?,?,?)",
                        (gid, vid, role),
                    )
            db.commit()
            time.sleep(0.1)

    total_v = db.execute("SELECT COUNT(*) FROM verses").fetchone()[0]
    total_g = db.execute("SELECT COUNT(*) FROM verse_groups WHERE is_christ_group=1").fetchone()[0]
    print(f"Done. {total_v} verses, {total_g} Christ-reference groups.")
    db.close()


app = flask.Flask(__name__)
app.secret_key = b"disciple_secret_key_change_in_prod"
bp = flask.Blueprint("disciple", __name__)


def _now():
    return datetime.datetime.utcnow().isoformat()


def _load_group(db, group_id):
    members = db.execute("""
        SELECT v.id, v.scripture_ref, v.text, v.verse_num, v.chapter,
               vgm.role, b.name as book_name
        FROM verse_group_members vgm
        JOIN verses v ON v.id = vgm.verse_id
        JOIN books b ON b.id = v.book_id
        WHERE vgm.group_id = ?
        ORDER BY v.chapter, v.verse_num
    """, (group_id,)).fetchall()
    tags = db.execute("""
        SELECT t.name FROM tags t
        JOIN group_tags gt ON gt.tag_id = t.id
        WHERE gt.group_id = ?
    """, (group_id,)).fetchall()
    note_row = db.execute("SELECT note FROM group_notes WHERE group_id=?", (group_id,)).fetchone()
    processed = db.execute("SELECT 1 FROM group_processed WHERE group_id=?", (group_id,)).fetchone()
    ref_members = [m for m in members if m["role"] == "christ_ref"]
    if ref_members:
        first, last = ref_members[0], ref_members[-1]
        if first["scripture_ref"] == last["scripture_ref"]:
            ref_range = first["scripture_ref"]
        elif first["book_name"] == last["book_name"] and first["chapter"] == last["chapter"]:
            ref_range = (
                f"{first['book_name']} {first['chapter']}"
                f":{first['verse_num']}–{last['verse_num']}"
            )
        else:
            ref_range = f"{first['scripture_ref']}–{last['scripture_ref']}"
    else:
        ref_range = members[0]["scripture_ref"] if members else ""
    return {
        "id": group_id,
        "members": [dict(m) for m in members],
        "tags": [t["name"] for t in tags],
        "note": note_row["note"] if note_row else "",
        "processed": bool(processed),
        "ref_range": ref_range,
    }


def _snippet(db, group_id):
    row = db.execute("""
        SELECT v.text FROM verse_group_members vgm
        JOIN verses v ON v.id = vgm.verse_id
        WHERE vgm.group_id = ? AND vgm.role = 'christ_ref'
        ORDER BY v.chapter, v.verse_num LIMIT 1
    """, (group_id,)).fetchone()
    if row:
        t = row["text"]
        return t[:80] + ("…" if len(t) > 80 else "")
    return ""


@app.context_processor
def _inject_stats():
    if DB_PATH is None:
        return {"total_groups": 0, "processed_groups": 0}
    db = get_db()
    try:
        total = db.execute(
            "SELECT COUNT(*) FROM verse_groups WHERE is_christ_group=1"
        ).fetchone()[0]
        done = db.execute("""
            SELECT COUNT(*) FROM group_processed gp
            JOIN verse_groups vg ON vg.id = gp.group_id
            WHERE vg.is_christ_group = 1
        """).fetchone()[0]
        return {"total_groups": total, "processed_groups": done}
    except Exception:
        return {"total_groups": 0, "processed_groups": 0}
    finally:
        db.close()


@bp.route("/")
def study():
    db = get_db()
    row = db.execute("""
        SELECT id FROM verse_groups
        WHERE is_christ_group=1
          AND id NOT IN (SELECT group_id FROM group_processed)
        ORDER BY RANDOM() LIMIT 1
    """).fetchone()
    all_tags = [r["name"] for r in db.execute("SELECT name FROM tags ORDER BY name").fetchall()]
    if not row:
        total = db.execute(
            "SELECT COUNT(*) FROM verse_groups WHERE is_christ_group=1"
        ).fetchone()[0]
        db.close()
        return flask.render_template("study.html", group=None, total=total, all_tags=all_tags)
    group = _load_group(db, row["id"])
    db.close()
    return flask.render_template("study.html", group=group, all_tags=all_tags)


@bp.route("/groups/<int:group_id>/process", methods=["POST"])
def process_group(group_id):
    note = flask.request.form.get("note", "").strip()
    tags_raw = flask.request.form.get("tags", "").strip()
    db = get_db()
    now = _now()
    existing = db.execute("SELECT id FROM group_notes WHERE group_id=?", (group_id,)).fetchone()
    if existing:
        db.execute(
            "UPDATE group_notes SET note=?, updated_at=? WHERE group_id=?",
            (note, now, group_id),
        )
    else:
        db.execute(
            "INSERT INTO group_notes (group_id, note, created_at, updated_at) VALUES (?,?,?,?)",
            (group_id, note, now, now),
        )
    db.execute("DELETE FROM group_tags WHERE group_id=?", (group_id,))
    for name in [t.strip() for t in tags_raw.split(",") if t.strip()]:
        db.execute("INSERT OR IGNORE INTO tags (name, created_at) VALUES (?,?)", (name, now))
        tag_id = db.execute("SELECT id FROM tags WHERE name=?", (name,)).fetchone()["id"]
        db.execute(
            "INSERT OR IGNORE INTO group_tags (group_id, tag_id) VALUES (?,?)",
            (group_id, tag_id),
        )
    db.execute(
        "INSERT OR IGNORE INTO group_processed (group_id, processed_at) VALUES (?,?)",
        (group_id, now),
    )
    db.commit()
    db.close()
    return flask.redirect(flask.url_for("disciple.study"))


@bp.route("/browse")
def browse():
    db = get_db()
    rows = db.execute("""
        SELECT vg.id,
               b.name as book_name, b.order_index,
               MIN(v.chapter) as chapter,
               MIN(CASE WHEN vgm.role='christ_ref' THEN v.verse_num END) as first_ref_verse,
               vg.manually_overridden,
               (SELECT 1 FROM group_processed gp WHERE gp.group_id=vg.id) as processed
        FROM verse_groups vg
        JOIN verse_group_members vgm ON vgm.group_id = vg.id
        JOIN verses v ON v.id = vgm.verse_id
        JOIN books b ON b.id = v.book_id
        WHERE vg.is_christ_group = 1
        GROUP BY vg.id
        ORDER BY b.order_index, chapter, first_ref_verse
    """).fetchall()
    groups = []
    for r in rows:
        gd = dict(r)
        loaded = _load_group(db, r["id"])
        gd["members"] = loaded["members"]
        gd["ref_range"] = loaded["ref_range"]
        gd["tags"] = loaded["tags"]
        gd["note"] = loaded["note"]
        gd["snippet"] = _snippet(db, r["id"])
        groups.append(gd)
    db.close()
    return flask.render_template("browse.html", groups=groups)


@bp.route("/tags")
def tags_list():
    db = get_db()
    rows = db.execute("""
        SELECT t.id, t.name, COUNT(gt.group_id) as count
        FROM tags t LEFT JOIN group_tags gt ON gt.tag_id = t.id
        GROUP BY t.id ORDER BY count DESC, t.name
    """).fetchall()
    db.close()
    return flask.render_template("tags.html", tags=rows)


@bp.route("/tags/<tag_name>")
def tag_detail(tag_name):
    db = get_db()
    tag = db.execute("SELECT id, name FROM tags WHERE name=?", (tag_name,)).fetchone()
    if not tag:
        flask.abort(404)
    rows = db.execute("""
        SELECT vg.id, b.name as book_name, b.order_index,
               MIN(v.chapter) as chapter,
               MIN(CASE WHEN vgm.role='christ_ref' THEN v.verse_num END) as first_ref_verse
        FROM verse_groups vg
        JOIN group_tags gtag ON gtag.group_id = vg.id AND gtag.tag_id = ?
        JOIN verse_group_members vgm ON vgm.group_id = vg.id
        JOIN verses v ON v.id = vgm.verse_id
        JOIN books b ON b.id = v.book_id
        GROUP BY vg.id
        ORDER BY b.order_index, chapter, first_ref_verse
    """, (tag["id"],)).fetchall()
    groups = []
    for r in rows:
        gd = dict(r)
        loaded = _load_group(db, r["id"])
        gd["members"] = loaded["members"]
        gd["ref_range"] = loaded["ref_range"]
        gd["note"] = loaded["note"]
        gd["snippet"] = _snippet(db, r["id"])
        groups.append(gd)
    db.close()
    return flask.render_template("tag_detail.html", tag=dict(tag), groups=groups)


@bp.route("/manage-tags")
def manage_tags():
    db = get_db()
    rows = db.execute("""
        SELECT t.id, t.name, COUNT(gt.group_id) as count
        FROM tags t LEFT JOIN group_tags gt ON gt.tag_id = t.id
        GROUP BY t.id ORDER BY t.name
    """).fetchall()
    db.close()
    return flask.render_template("manage_tags.html", tags=rows)


@bp.route("/tags/<int:tag_id>/rename", methods=["POST"])
def rename_tag(tag_id):
    new_name = flask.request.form.get("name", "").strip()
    if new_name:
        db = get_db()
        db.execute("UPDATE tags SET name=? WHERE id=?", (new_name, tag_id))
        db.commit()
        db.close()
    return flask.redirect(flask.url_for("disciple.manage_tags"))


@bp.route("/tags/merge", methods=["POST"])
def merge_tags():
    source_id = flask.request.form.get("source_id", type=int)
    target_id = flask.request.form.get("target_id", type=int)
    if source_id and target_id and source_id != target_id:
        db = get_db()
        db.execute(
            "UPDATE OR IGNORE group_tags SET tag_id=? WHERE tag_id=?",
            (target_id, source_id),
        )
        db.execute("DELETE FROM group_tags WHERE tag_id=?", (source_id,))
        db.execute("DELETE FROM tags WHERE id=?", (source_id,))
        db.commit()
        db.close()
    return flask.redirect(flask.url_for("disciple.manage_tags"))


@bp.route("/groups/<int:group_id>/toggle-christ", methods=["POST"])
def toggle_christ(group_id):
    db = get_db()
    db.execute("""
        UPDATE verse_groups
        SET is_christ_group = NOT is_christ_group, manually_overridden = 1
        WHERE id = ?
    """, (group_id,))
    db.commit()
    db.close()
    return flask.redirect(flask.request.referrer or flask.url_for("disciple.browse"))


def run():
    parser = argparse.ArgumentParser(description="Disciple study server")
    parser.add_argument("--port",      type=int, default=6363)
    parser.add_argument("--subdomain", type=str, default="/disciple")
    parser.add_argument("--db-path",   type=str, required=True)
    args = parser.parse_args()
    global DB_PATH
    DB_PATH = args.db_path
    init_db()
    app.register_blueprint(bp, url_prefix=args.subdomain)
    app.run(host="0.0.0.0", port=args.port)


def ingest():
    parser = argparse.ArgumentParser(description="Populate Disciple DB from nephi.org")
    parser.add_argument("--db-path", type=str, required=True)
    parser.add_argument("--force",   action="store_true")
    args = parser.parse_args()
    do_ingest(args.db_path, force=args.force)
