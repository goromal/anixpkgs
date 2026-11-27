# la_quiz_web

A web-based LA geography quiz game with mobile support.

A mobile-friendly Flask web application for testing knowledge of Los Angeles geography.
Places are taught a few at a time in rounds: study them on a zoomed map, practice until
each is answered correctly twice in a row after a miss, then pass a final check with no
misses. Spaced review brings missed places back in later rounds, and per-place mastery
persists across visits.

## Usage

```bash
usage: la-quiz-web [-h] [--port PORT] [--subdomain SUBDOMAIN]
                   [--db-path DB_PATH] [--maps-dir MAPS_DIR]

options:
  -h, --help            show this help message and exit
  --port PORT           Port to run the server on
  --subdomain SUBDOMAIN
                        Subdomain for a reverse proxy
  --db-path DB_PATH     Path to SQLite database
  --maps-dir MAPS_DIR   Directory containing map images
```

