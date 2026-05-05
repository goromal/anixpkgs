#!/usr/bin/env python3
"""
Migrate LA Quiz JSON data to SQLite database.

Usage:
    python migrate_json_to_db.py --db-path /path/to/la_quiz.db --maps-dir /path/to/maps

This script will:
1. Read JSON files from ~/games/la-quiz/
2. Copy map images to the maps directory
3. Create regions and cities in the database
"""

import json
import sqlite3
import argparse
import shutil
from pathlib import Path
from PIL import Image

# Region mapping
REGIONS = {
    'N': {'name': 'North LA', 'json': 'GLAA-N.json', 'img': 'GLAA-N.png'},
    'C': {'name': 'Central LA', 'json': 'GLAA-C.json', 'img': 'GLAA-C.png'},
    'E': {'name': 'East LA', 'json': 'GLAA-E.json', 'img': 'GLAA-E.png'},
    'S': {'name': 'South LA', 'json': 'GLAA-S.json', 'img': 'GLAA-S.png'},
}

def get_image_dimensions(image_path):
    """Get image width and height."""
    with Image.open(image_path) as img:
        return img.width, img.height

def migrate_data(db_path, json_dir, maps_dir, images_dir):
    """Migrate JSON data to SQLite database."""

    # Create maps directory if it doesn't exist
    Path(maps_dir).mkdir(parents=True, exist_ok=True)

    # Connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS regions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT UNIQUE NOT NULL,
            map_image TEXT NOT NULL,
            map_width INTEGER NOT NULL,
            map_height INTEGER NOT NULL
        )
    ''')

    cursor.execute('''
        CREATE TABLE IF NOT EXISTS cities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            region_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            FOREIGN KEY (region_id) REFERENCES regions (id)
        )
    ''')

    # Clear existing data
    cursor.execute('DELETE FROM cities')
    cursor.execute('DELETE FROM regions')

    # Process each region
    for region_code, region_info in REGIONS.items():
        json_path = Path(json_dir) / region_info['json']
        img_src_path = Path(images_dir) / region_info['img']
        img_dest_path = Path(maps_dir) / region_info['img']

        # Check if files exist
        if not json_path.exists():
            print(f"Warning: JSON file not found: {json_path}")
            continue

        if not img_src_path.exists():
            print(f"Warning: Image file not found: {img_src_path}")
            continue

        # Copy image to maps directory
        shutil.copy2(img_src_path, img_dest_path)
        print(f"Copied {img_src_path} to {img_dest_path}")

        # Get image dimensions
        width, height = get_image_dimensions(img_dest_path)

        # Insert region
        cursor.execute(
            'INSERT INTO regions (name, map_image, map_width, map_height) VALUES (?, ?, ?, ?)',
            (region_info['name'], region_info['img'], width, height)
        )
        region_id = cursor.lastrowid
        print(f"Added region: {region_info['name']} (ID: {region_id})")

        # Read JSON data
        with open(json_path, 'r') as f:
            data = json.load(f)

        # Insert cities
        cities_added = 0
        for city in data['cities']:
            # Skip cities with invalid coordinates
            if city['x'] < 0 or city['y'] < 0:
                print(f"  Skipping city with invalid coordinates: {city['name']}")
                continue

            cursor.execute(
                'INSERT INTO cities (region_id, name, x, y) VALUES (?, ?, ?, ?)',
                (region_id, city['name'], city['x'], city['y'])
            )
            cities_added += 1

        print(f"  Added {cities_added} cities")

    # Commit changes
    conn.commit()

    # Print summary
    cursor.execute('SELECT COUNT(*) FROM regions')
    region_count = cursor.fetchone()[0]

    cursor.execute('SELECT COUNT(*) FROM cities')
    city_count = cursor.fetchone()[0]

    print(f"\nMigration complete!")
    print(f"Total regions: {region_count}")
    print(f"Total cities: {city_count}")

    conn.close()

def main():
    parser = argparse.ArgumentParser(description='Migrate LA Quiz JSON data to SQLite database')
    parser.add_argument('--db-path', required=True, help='Path to SQLite database file')
    parser.add_argument('--json-dir', default=str(Path.home() / 'games' / 'la-quiz'),
                        help='Directory containing JSON files (default: ~/games/la-quiz)')
    parser.add_argument('--maps-dir', required=True, help='Directory to store map images')
    parser.add_argument('--images-dir', help='Directory containing source map images (default: same as json-dir)')

    args = parser.parse_args()

    # Use json-dir as images-dir if not specified
    images_dir = args.images_dir if args.images_dir else args.json_dir

    migrate_data(args.db_path, args.json_dir, args.maps_dir, images_dir)

if __name__ == '__main__':
    main()
