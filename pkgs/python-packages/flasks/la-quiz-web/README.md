# LA Quiz Web

A mobile-friendly web-based version of the LA Geography Quiz game.

## Features

- **Mobile-Responsive**: Touch-friendly interface optimized for mobile devices
- **SQLite Database**: Stores city locations in a database instead of JSON files
- **Multiple Regions**: Support for North, Central, East, and South LA
- **Score Tracking**: Session-based score tracking with accuracy feedback
- **Real-time Feedback**: Visual markers showing correct location and distance

## Installation

The application is packaged with Nix. Add it to your system configuration:

```nix
{
  services.la-quiz-web = {
    enable = true;
    dataDir = "/data/andrew/la-quiz-web";  # Optional: customize data directory
    port = 5050;  # Optional: customize port
    subdomain = "/la-quiz";  # Optional: customize subdomain
  };
}
```

## Setup

### 1. Initialize the Database

First, run the migration script to populate the database from JSON files:

```bash
# Create data directories
mkdir -p /data/andrew/la-quiz-web/maps

# Run migration
python migrate_json_to_db.py \
  --db-path /data/andrew/la-quiz-web/la_quiz.db \
  --json-dir ~/games/la-quiz \
  --maps-dir /data/andrew/la-quiz-web/maps \
  --images-dir ~/dev/packages/sources/anixdata/data/apps/la-quiz
```

### 2. Start the Server

If using the NixOS module, the service will start automatically. Otherwise:

```bash
la-quiz-web --port 5050 --subdomain /la-quiz \
  --db-path /data/andrew/la-quiz-web/la_quiz.db \
  --maps-dir /data/andrew/la-quiz-web/maps
```

### 3. Access the Application

Navigate to `http://localhost:5050/la-quiz/` (or your configured subdomain).

## Usage

### Normal Quiz Mode

1. Select a region (North, Central, East, or South LA)
2. A city name will be displayed
3. Tap/click the location on the map where you think the city is located
4. The app will show if you were correct (within 20 pixels)
5. Your score is tracked throughout the session

### Debug Mode

Debug mode allows you to update city coordinates and add new cities directly from the web interface:

1. Click the **Debug Mode** button to enable debug mode
2. When enabled, you'll see a debug panel with:
   - Current city information (name, ID, coordinates)
   - Last click coordinates
   - Options to set coordinates or add new cities

**Setting Coordinates:**
1. Click "Set Coordinates" button
2. Click on the map where the city should be located
3. Confirm the new coordinates
4. The database will be updated immediately

**Adding New Cities:**
1. Click "Add New City" button
2. Enter the city name in the form
3. Click on the map to set the coordinates
4. Click "Save City" to add it to the database
5. The page will reload to include the new city in the quiz

Debug mode is session-based, so it persists only for your current browser session.

## Architecture

### Database Schema

**regions table:**
- `id`: Primary key
- `name`: Region name (e.g., "North LA")
- `map_image`: Filename of the map image
- `map_width`: Width of the map image
- `map_height`: Height of the map image

**cities table:**
- `id`: Primary key
- `region_id`: Foreign key to regions table
- `name`: City name
- `x`: X coordinate on the map
- `y`: Y coordinate on the map

### Files

- `la_quiz_web.py`: Flask application with all routes and game logic
- `templates/index.html`: Region selection page
- `templates/quiz.html`: Quiz interface with interactive map
- `migrate_json_to_db.py`: Migration utility to import JSON data
- `module.nix`: NixOS service module
- `default.nix`: Nix package definition

## Development

### Running Locally

```bash
# Install dependencies
pip install flask pillow

# Create test database
python migrate_json_to_db.py \
  --db-path ./test.db \
  --json-dir ~/games/la-quiz \
  --maps-dir ./test-maps \
  --images-dir ~/dev/packages/sources/anixdata/data/apps/la-quiz

# Run server
python la_quiz_web.py --port 5000 --subdomain / --db-path ./test.db --maps-dir ./test-maps
```

### Mobile Testing

The application is designed to work on mobile devices. Test with:
- Chrome DevTools mobile emulation
- Real mobile devices on the same network
- Different screen sizes and orientations

## Differences from Original

The web version differs from the original Tkinter application in several ways:

- **Database vs JSON**: Uses SQLite instead of JSON files for better scalability
- **Web-based**: Accessible from any device with a browser
- **Mobile-first**: Touch-optimized interface
- **Session-based**: Tracks scores per browser session
- **Enhanced Debug Mode**: Toggle-able debug mode with in-browser coordinate editing and city addition (vs. command-line only in original)

## Future Enhancements

Potential improvements:
- User accounts and persistent high scores
- Leaderboards
- Difficulty levels (varying proximity requirements)
- Additional regions
- Time-based challenges
- Multiplayer mode
