# disciple

A Book of Mormon Christ-reference study tool.

A Flask web application for studying Book of Mormon passages that
reference Jesus Christ. Ingests all verses from the nephi.org API,
groups consecutive Christ-reference verses with surrounding context,
and provides a study interface for annotating and tagging passages.

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
```

