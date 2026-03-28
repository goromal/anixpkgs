# self-tester-app

A self-testing and exam tool with rote, multiple choice, and short answer modes.

A Flask web application for accumulating and taking mini exams to test
memorization and knowledge of particular subjects. Supports rote memorization
checks (fuzzy-graded fill-in-the-blank), multiple choice tests (AI-generated,
locally graded), and short answer tests (AI-generated and AI-graded).
Exam definitions and results are stored in a persistent SQLite database.

## Usage

```bash
usage: tester [-h] [--port PORT] [--subdomain SUBDOMAIN] [--db-path DB_PATH]
              [--data-dir DATA_DIR]

options:
  -h, --help            show this help message and exit
  --port PORT           Port to run the server on
  --subdomain SUBDOMAIN
                        Subdomain for a reverse proxy
  --db-path DB_PATH     Path to SQLite database
  --data-dir DATA_DIR   Data directory for uploads and DB
```

