# grafana_dash

Generate, sanitize, and lint Grafana dashboards.


## Usage

```bash
usage: grafana_dash [-h] {sanitize,render,lint} ...

Generate, sanitize, and lint Grafana dashboards for anixpkgs metricsNode.

positional arguments:
  {sanitize,render,lint}
    sanitize            normalize exported dashboards
    render              render dashboards from a spec
    lint                validate a directory of dashboards

options:
  -h, --help            show this help message and exit
```

### render


```bash
usage: grafana_dash render [-h] --spec FILE --out DIR

options:
  -h, --help   show this help message and exit
  --spec FILE  dashboard spec JSON from Nix
  --out DIR    directory to write dashboards into
```

### sanitize


```bash
usage: grafana_dash sanitize [-h] --out DIR inputs [inputs ...]

positional arguments:
  inputs      exported dashboard JSON files

options:
  -h, --help  show this help message and exit
  --out DIR   directory to write sanitized dashboards into
```

### lint


```bash
usage: grafana_dash lint [-h] DIR

positional arguments:
  DIR         directory of dashboard JSON to validate

options:
  -h, --help  show this help message and exit
```

