import os
import argparse
import random
import sqlite3
import math
from pathlib import Path
import flask
from werkzeug.security import generate_password_hash, check_password_hash

parser = argparse.ArgumentParser()
parser.add_argument("--port", action="store", type=int, default=5000, help="Port to run the server on")
parser.add_argument("--subdomain", action="store", type=str, default="/la-quiz", help="Subdomain for a reverse proxy")
parser.add_argument("--db-path", action="store", type=str, default="", help="Path to SQLite database")
parser.add_argument("--maps-dir", action="store", type=str, default="", help="Directory containing map images")
args = parser.parse_args()

urlroot = args.subdomain
if urlroot != "/":
    urlroot += "/"
url_for_prefix = args.subdomain.replace("/", "").replace("-", "_")
if len(url_for_prefix) > 0:
    url_for_prefix += "."

bp = flask.Blueprint("la_quiz", __name__, url_prefix=args.subdomain)

PWD = os.getcwd()
if args.db_path and args.db_path[0] == '/':
    DB_PATH = args.db_path
else:
    DB_PATH = os.path.join(PWD, args.db_path if args.db_path else "la_quiz.db")

if args.maps_dir and args.maps_dir[0] == '/':
    MAPS_DIR = args.maps_dir
else:
    MAPS_DIR = os.path.join(PWD, args.maps_dir if args.maps_dir else "maps")

app = flask.Flask(__name__, static_url_path=args.subdomain + "/static", static_folder=MAPS_DIR)
app.secret_key = b"la_quiz_secret_key_change_in_production"

def get_db():
    """Get database connection."""
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db

def init_db():
    """Initialize database schema."""
    db = get_db()
    db.execute('''
        CREATE TABLE IF NOT EXISTS regions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            map_image TEXT NOT NULL,
            map_width INTEGER NOT NULL,
            map_height INTEGER NOT NULL
        )
    ''')
    db.execute('''
        CREATE TABLE IF NOT EXISTS cities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            region_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            FOREIGN KEY (region_id) REFERENCES regions (id)
        )
    ''')
    db.commit()
    db.close()

# Initialize DB on startup
init_db()

def get_regions():
    """Get all regions."""
    db = get_db()
    regions = db.execute('SELECT * FROM regions ORDER BY name').fetchall()
    db.close()
    return [dict(r) for r in regions]

def get_cities_by_region(region_id):
    """Get all cities for a region."""
    db = get_db()
    cities = db.execute('SELECT * FROM cities WHERE region_id = ?', (region_id,)).fetchall()
    db.close()
    return [dict(c) for c in cities]

def get_region_by_id(region_id):
    """Get region by ID."""
    db = get_db()
    region = db.execute('SELECT * FROM regions WHERE id = ?', (region_id,)).fetchone()
    db.close()
    return dict(region) if region else None

@bp.route("/")
def index():
    """Main page - region selection."""
    # Initialize debug mode if not set
    if 'debug_mode' not in flask.session:
        flask.session['debug_mode'] = False

    regions = get_regions()
    return flask.render_template(
        "index.html",
        urlroot=urlroot,
        regions=regions,
        debug_mode=flask.session.get('debug_mode', False)
    )

@bp.route("/quiz/<int:region_id>")
def quiz(region_id):
    """Quiz page for a specific region."""
    region = get_region_by_id(region_id)
    if not region:
        flask.flash("Region not found")
        return flask.redirect(flask.url_for(url_for_prefix + 'index'))

    cities = get_cities_by_region(region_id)

    # Initialize debug mode if not set
    if 'debug_mode' not in flask.session:
        flask.session['debug_mode'] = False

    # If no cities and not in debug mode, redirect with message
    if not cities and not flask.session.get('debug_mode', False):
        flask.flash("No cities found for this region. Enable debug mode to add cities.")
        return flask.redirect(flask.url_for(url_for_prefix + 'index'))

    # If no cities but in debug mode, show setup page
    if not cities:
        return flask.render_template(
            "setup_region.html",
            urlroot=urlroot,
            region=region,
            debug_mode=True
        )

    # Initialize session if needed
    if 'region_id' not in flask.session or flask.session['region_id'] != region_id:
        flask.session['region_id'] = region_id
        flask.session['city_indices'] = list(range(len(cities)))
        random.shuffle(flask.session['city_indices'])
        flask.session['current_index'] = 0
        flask.session['score'] = 0
        flask.session['total_guesses'] = 0
        flask.session['awaiting_feedback'] = False
        flask.session['last_result'] = None

    current_idx = flask.session['city_indices'][flask.session['current_index']]
    current_city = cities[current_idx]

    return flask.render_template(
        "quiz.html",
        urlroot=urlroot,
        region=region,
        city=current_city,
        score=flask.session.get('score', 0),
        total=flask.session.get('total_guesses', 0),
        awaiting_feedback=flask.session.get('awaiting_feedback', False),
        last_result=flask.session.get('last_result'),
        debug_mode=flask.session.get('debug_mode', False)
    )

@bp.route("/check/<int:region_id>", methods=["POST"])
def check_guess(region_id):
    """Check user's guess."""
    data = flask.request.json
    click_x = data.get('x')
    click_y = data.get('y')

    if click_x is None or click_y is None:
        return flask.jsonify({"error": "Invalid coordinates"}), 400

    cities = get_cities_by_region(region_id)
    current_idx = flask.session['city_indices'][flask.session['current_index']]
    current_city = cities[current_idx]

    # Calculate distance
    distance = math.sqrt((current_city['x'] - click_x) ** 2 + (current_city['y'] - click_y) ** 2)
    is_correct = distance < 75

    # Update session
    flask.session['total_guesses'] += 1
    if is_correct:
        flask.session['score'] += 1

    # Prepare for next city
    flask.session['current_index'] += 1
    if flask.session['current_index'] >= len(cities):
        flask.session['current_index'] = 0
        flask.session['city_indices'] = list(range(len(cities)))
        random.shuffle(flask.session['city_indices'])

    next_idx = flask.session['city_indices'][flask.session['current_index']]
    next_city = cities[next_idx]

    return flask.jsonify({
        "correct": is_correct,
        "distance": round(distance, 1),
        "correct_x": current_city['x'],
        "correct_y": current_city['y'],
        "next_city": next_city['name'],
        "score": flask.session['score'],
        "total": flask.session['total_guesses']
    })

@bp.route("/reset/<int:region_id>", methods=["POST"])
def reset_quiz(region_id):
    """Reset the quiz for a region."""
    cities = get_cities_by_region(region_id)
    flask.session['region_id'] = region_id
    flask.session['city_indices'] = list(range(len(cities)))
    random.shuffle(flask.session['city_indices'])
    flask.session['current_index'] = 0
    flask.session['score'] = 0
    flask.session['total_guesses'] = 0
    flask.session['awaiting_feedback'] = False
    flask.session['last_result'] = None
    return flask.jsonify({"status": "reset"})

@bp.route("/toggle-debug", methods=["POST"])
def toggle_debug():
    """Toggle debug mode."""
    flask.session['debug_mode'] = not flask.session.get('debug_mode', False)
    return flask.jsonify({"debug_mode": flask.session['debug_mode']})

@bp.route("/update-coordinates/<int:city_id>", methods=["POST"])
def update_coordinates(city_id):
    """Update coordinates for a city (debug mode only)."""
    if not flask.session.get('debug_mode', False):
        return flask.jsonify({"error": "Debug mode not enabled"}), 403

    data = flask.request.json
    x = data.get('x')
    y = data.get('y')

    if x is None or y is None:
        return flask.jsonify({"error": "Invalid coordinates"}), 400

    db = get_db()
    db.execute('UPDATE cities SET x = ?, y = ? WHERE id = ?', (x, y, city_id))
    db.commit()
    db.close()

    return flask.jsonify({"status": "updated", "city_id": city_id, "x": x, "y": y})

@bp.route("/add-city/<int:region_id>", methods=["POST"])
def add_city(region_id):
    """Add a new city to a region (debug mode only)."""
    if not flask.session.get('debug_mode', False):
        return flask.jsonify({"error": "Debug mode not enabled"}), 403

    data = flask.request.json
    name = data.get('name')
    x = data.get('x')
    y = data.get('y')

    if not name or x is None or y is None:
        return flask.jsonify({"error": "Missing required fields"}), 400

    db = get_db()
    cursor = db.execute(
        'INSERT INTO cities (region_id, name, x, y) VALUES (?, ?, ?, ?)',
        (region_id, name, x, y)
    )
    city_id = cursor.lastrowid
    db.commit()
    db.close()

    return flask.jsonify({
        "status": "added",
        "city_id": city_id,
        "name": name,
        "x": x,
        "y": y
    })

@bp.route("/cities/<int:region_id>", methods=["GET"])
def list_cities(region_id):
    """Get all cities for a region (for debug mode city management)."""
    if not flask.session.get('debug_mode', False):
        return flask.jsonify({"error": "Debug mode not enabled"}), 403

    cities = get_cities_by_region(region_id)
    return flask.jsonify({"cities": cities})

def run():
    global args
    app.register_blueprint(bp)
    app.run(host="0.0.0.0", port=args.port)

if __name__ == "__main__":
    run()
