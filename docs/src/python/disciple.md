# disciple

A Book of Mormon Christ-reference study tool.

A Flask web application for studying Book of Mormon passages that
reference Jesus Christ. Ingests all verses from the nephi.org API,
groups consecutive Christ-reference verses with surrounding context,
and provides a study interface for annotating and tagging passages.

Includes the `disciple-report` CLI, which reports study activity for a
given local calendar day (yesterday by default, attributed by each
group's processed_at timestamp) to the tactical server's "Spiritual
reflection" survey question (1 processed group = partial credit,
2+ = full credit). Stateless and safe to re-run.

## Usage

```bash
usage: disciple [-h] [--port PORT] [--subdomain SUBDOMAIN] --db-path DB_PATH

Disciple study server

options:
  -h, --help            show this help message and exit
  --port PORT
  --subdomain SUBDOMAIN
  --db-path DB_PATH
``````bash
usage: disciple-ingest [-h] --db-path DB_PATH [--force]

Populate Disciple DB from nephi.org

options:
  -h, --help         show this help message and exit
  --db-path DB_PATH
  --force
``````bash
usage: disciple-report [-h] --db-path DB_PATH [--tactical-port TACTICAL_PORT]
                       [--report-date REPORT_DATE] [--dry-run]

Report disciple study activity to the tactical server

options:
  -h, --help            show this help message and exit
  --db-path DB_PATH
  --tactical-port TACTICAL_PORT
  --report-date REPORT_DATE
                        Local date (YYYY-MM-DD) to report for; defaults to
                        yesterday
  --dry-run
```

