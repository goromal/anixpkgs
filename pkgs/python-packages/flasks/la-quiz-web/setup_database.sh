#!/usr/bin/env bash
# Setup script for LA Quiz Web database

set -e

# Default paths
DATA_DIR="${1:-/data/andrew/la-quiz-web}"
JSON_DIR="${2:-$HOME/games/la-quiz}"
IMAGES_DIR="${3:-$HOME/dev/packages/sources/anixdata/data/apps/la-quiz}"

DB_PATH="$DATA_DIR/la_quiz.db"
MAPS_DIR="$DATA_DIR/maps"

echo "Setting up LA Quiz Web database..."
echo "Data directory: $DATA_DIR"
echo "JSON directory: $JSON_DIR"
echo "Images directory: $IMAGES_DIR"
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "$DATA_DIR"
mkdir -p "$MAPS_DIR"

# Check if required directories exist
if [ ! -d "$JSON_DIR" ]; then
    echo "Error: JSON directory not found: $JSON_DIR"
    exit 1
fi

if [ ! -d "$IMAGES_DIR" ]; then
    echo "Error: Images directory not found: $IMAGES_DIR"
    exit 1
fi

# Run migration
echo "Running database migration..."
python3 "$(dirname "$0")/migrate_json_to_db.py" \
    --db-path "$DB_PATH" \
    --json-dir "$JSON_DIR" \
    --maps-dir "$MAPS_DIR" \
    --images-dir "$IMAGES_DIR"

echo ""
echo "Setup complete!"
echo "Database created at: $DB_PATH"
echo "Maps copied to: $MAPS_DIR"
echo ""
echo "You can now start the server with:"
echo "  la-quiz-web --port 5050 --subdomain /la-quiz --db-path $DB_PATH --maps-dir $MAPS_DIR"
