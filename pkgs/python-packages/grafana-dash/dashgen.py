"""Generate, sanitize, and lint Grafana dashboards for anixpkgs metricsNode."""

import argparse
import copy
import json
import os
import re
import sys

PROM_UID = "anix-prometheus"
LOKI_UID = "anix-loki"

# Datasource uids that are legal in provisioned output.
BUILTIN_UIDS = {"grafana", "-- Grafana --"}
KNOWN_UIDS = {PROM_UID, LOKI_UID} | BUILTIN_UIDS

_TYPE_TO_UID = {"prometheus": PROM_UID, "loki": LOKI_UID}

# Keys that only mean something to the interactive importer.
_IMPORT_ONLY_KEYS = ("__inputs", "__elements", "__requires")

# A dashboard name becomes a filename, so it has to be a plain identifier: `..` or
# a `/` would put the file outside the output directory. Both ends check it, and
# both checks earn their keep. `render_files` rejects the name on the way in --
# and only that check can see a name that escapes, because a file written outside
# `--out` is one `lint` can never list. `lint` rejects the filename on the way
# out, which covers dashboards that never went through `render` at all.
_VALID_STEM = re.compile(r"[A-Za-z0-9_-]+")
_STEM_RULE = "allowed: A-Z a-z 0-9 _ -"


def _load_json(path):
    """Load JSON from ``path``, naming the file if it does not parse.

    A bare ``JSONDecodeError`` says only "line 1 column 2" -- useless when the
    build log is the whole diagnostic and the command read a directory of files.
    """
    with open(path) as f:
        try:
            return json.load(f)
        except json.JSONDecodeError as error:
            raise ValueError(f"{path}: {error}") from error


def _rewrite_datasources(node):
    """Recursively rewrite every ``datasource`` object to a pinned uid."""
    if isinstance(node, dict):
        ds = node.get("datasource")
        # Only the object form is rewritten. Pre-Grafana-8 exports use a bare
        # string ("datasource": "${DS_PROMETHEUS}"), which passes through
        # untouched; `lint` is the backstop that rejects one if it ever appears.
        if isinstance(ds, dict):
            uid = _TYPE_TO_UID.get(ds.get("type"))
            if uid is not None:
                ds["uid"] = uid
        for value in node.values():
            _rewrite_datasources(value)
    elif isinstance(node, list):
        for item in node:
            _rewrite_datasources(item)


def sanitize_dashboard(dashboard):
    """Turn an exported dashboard into a provisionable one."""
    out = copy.deepcopy(dashboard)

    for key in _IMPORT_ONLY_KEYS:
        out.pop(key, None)

    _rewrite_datasources(out)

    templating = out.get("templating")
    if isinstance(templating, dict) and isinstance(templating.get("list"), list):
        templating["list"] = [
            v for v in templating["list"] if v.get("type") != "datasource"
        ]

    out["id"] = None
    out["version"] = 1
    return out


def sanitize_files(inputs, out_dir):
    """Sanitize each input dashboard into ``out_dir``, keyed by its basename.

    Raises ``ValueError`` if two inputs share a basename, since they would
    otherwise silently overwrite each other.
    """
    sources_by_name = {}
    for path in inputs:
        name = os.path.basename(path)
        if name in sources_by_name:
            raise ValueError(
                f"duplicate output name {name!r}: {sources_by_name[name]} and "
                f"{path} would both be written to {os.path.join(out_dir, name)}"
            )
        sources_by_name[name] = path

    os.makedirs(out_dir, exist_ok=True)
    for name, path in sources_by_name.items():
        dashboard = _load_json(path)
        with open(os.path.join(out_dir, name), "w") as f:
            json.dump(sanitize_dashboard(dashboard), f, indent=2, sort_keys=True)


_PANEL_HEIGHT = 8
_GRID_WIDTH = 24
_DEFAULT_DASHBOARD = "diagnostics"
_DEFAULT_GROUP = "General"


def _target(panel):
    if panel["kind"] == "logs":
        # The doubled braces here are str.format escapes producing a literal
        # LogQL selector, `{tag="..."}`. Contrast `{{instance}}` below, which is
        # not an escape at all: it is Grafana's own legend-token syntax and
        # reaches the dashboard verbatim, doubled braces included.
        return {"expr": '{{tag="{0}"}}'.format(panel["tag"]), "refId": "A",
                "queryType": "range"}
    # Missing both `expr` and `metric` is a spec bug; raise rather than emit a
    # silently blank panel, matching the KeyError the logs branch raises above.
    expr = panel.get("expr") or panel["metric"]
    return {"expr": expr, "refId": "A", "legendFormat": "{{instance}}"}


def _datasource(panel):
    uid = LOKI_UID if panel["kind"] == "logs" else PROM_UID
    dtype = "loki" if panel["kind"] == "logs" else "prometheus"
    return {"type": dtype, "uid": uid}


def _panel_type(panel):
    # `logs` maps to Grafana's `table` panel, not its `logs` panel, deliberately:
    # the existing hand-exported dashboards already render Loki queries as tables,
    # so this preserves parity with what is deployed today. Grafana's `logs` panel
    # is the more idiomatic choice for a log stream and would be a genuine
    # improvement, but it is a user-visible change outside this project's scope.
    return {"timeseries": "timeseries", "stat": "stat", "logs": "table"}[panel["kind"]]


def render_dashboard(name, panels, hostname):
    """Build a dashboard dict from spec panels belonging to ``name``."""
    # dicts preserve insertion order, so groups come out by first appearance.
    groups = {}
    for panel in panels:
        if panel.get("dashboard", _DEFAULT_DASHBOARD) == name:
            groups.setdefault(panel.get("group", _DEFAULT_GROUP), []).append(panel)

    out_panels = []
    panel_id = 1
    y = 0

    for group, group_panels in groups.items():
        out_panels.append({
            "type": "row", "title": group, "id": panel_id, "collapsed": False,
            "gridPos": {"h": 1, "w": _GRID_WIDTH, "x": 0, "y": y}, "panels": [],
        })
        panel_id += 1
        y += 1

        x = 0
        for panel in group_panels:
            width = min(panel.get("width", _GRID_WIDTH // 2), _GRID_WIDTH)
            if x + width > _GRID_WIDTH:
                x = 0
                y += _PANEL_HEIGHT
            out_panels.append({
                "type": _panel_type(panel),
                "title": panel["title"],
                "id": panel_id,
                "datasource": _datasource(panel),
                # _datasource is called twice on purpose: aliasing one dict into
                # both the panel and its target would share mutable state.
                "targets": [{**_target(panel), "datasource": _datasource(panel)}],
                "fieldConfig": {
                    "defaults": {"unit": panel.get("unit", "short")}, "overrides": [],
                },
                "gridPos": {"h": _PANEL_HEIGHT, "w": width, "x": x, "y": y},
            })
            panel_id += 1
            x += width
        y += _PANEL_HEIGHT

    return {
        "uid": f"anix-{name}",
        "title": name.replace("-", " ").title(),
        "tags": ["anix", hostname],
        "timezone": "browser",
        "schemaVersion": 39,
        "version": 1,
        "id": None,
        "refresh": "1m",
        "time": {"from": "now-6h", "to": "now"},
        "templating": {"list": []},
        "annotations": {"list": []},
        "panels": out_panels,
    }


def render_files(spec, out_dir):
    """Render every dashboard named in ``spec`` into ``out_dir``.

    Raises ``ValueError`` if a dashboard name is not a plain identifier.
    """
    names = []
    for panel in spec["panels"]:
        name = panel.get("dashboard", _DEFAULT_DASHBOARD)
        if name not in names:
            names.append(name)

    # Checked before anything is created, so a bad name leaves no partial output
    # behind -- the same policy as the duplicate-basename check in sanitize_files.
    for name in names:
        if not _VALID_STEM.fullmatch(name):
            raise ValueError(
                f"dashboard name {name!r} is not a plain identifier "
                f"({_STEM_RULE}), so it would not stay inside {out_dir}"
            )

    os.makedirs(out_dir, exist_ok=True)
    for name in names:
        dashboard = render_dashboard(name, spec["panels"], spec["hostname"])
        with open(os.path.join(out_dir, f"{name}.json"), "w") as f:
            json.dump(dashboard, f, indent=2, sort_keys=True)


def _iter_datasources(node):
    """Yield every ``datasource`` value under ``node``, at any depth.

    The read-only twin of ``_rewrite_datasources``. Depth is the whole point:
    dashboards carry datasources on panels, on each panel's targets, on panels
    nested inside a collapsed row, and on template variables.

    Both shapes are yielded as-is -- the object form and the pre-Grafana-8 bare
    string -- because they are separate defects and get separate reports.
    """
    if isinstance(node, dict):
        ds = node.get("datasource")
        if isinstance(ds, (dict, str)):
            yield ds
        for value in node.values():
            yield from _iter_datasources(value)
    elif isinstance(node, list):
        for item in node:
            yield from _iter_datasources(item)


def lint_dashboards(dashboards):
    """Return a list of problems across ``{filename: dashboard}``.

    An empty list means every dashboard is safe to provision. Row panels carry no
    ``datasource`` of their own and are simply not reported on.
    """
    errors = []
    seen_uids = {}

    # Sorted so a duplicate uid is always blamed on the same file, whatever order
    # the caller happened to build the mapping in.
    for filename, dashboard in sorted(dashboards.items()):
        stem = os.path.splitext(filename)[0]
        if not _VALID_STEM.fullmatch(stem):
            errors.append(
                f"{filename}: dashboard name {stem!r} is not a plain identifier "
                f"({_STEM_RULE})"
            )

        uid = dashboard.get("uid")
        title = dashboard.get("title")
        if not uid:
            errors.append(f"{filename}: missing uid")
        if not title:
            errors.append(f"{filename}: missing title")

        if uid:
            if uid in seen_uids:
                errors.append(
                    f"{filename}: duplicate dashboard uid {uid!r} "
                    f"(also in {seen_uids[uid]})"
                )
            else:
                seen_uids[uid] = filename

        found = list(_iter_datasources(dashboard))

        # Deduplicated per dashboard: one bad uid repeated across 400 panels is one
        # finding, and a build log is the only diagnostic anyone gets. Sorting keeps
        # the report stable.
        for ds in sorted({d for d in found if isinstance(d, str)}):
            # `sanitize` deliberately leaves the string form alone, so lint is the
            # only thing between one and a broken host. It is wrong whatever the
            # string says, including when it names a datasource that exists.
            errors.append(
                f"{filename}: string-form datasource {ds!r} "
                f"is a pre-Grafana-8 shape and will not resolve"
            )

        uids = {d["uid"] for d in found if isinstance(d, dict) and "uid" in d}
        # `repr` as the sort key so a uid that is not a string at all still orders.
        for ds_uid in sorted(uids, key=repr):
            if isinstance(ds_uid, str) and "${" in ds_uid:
                errors.append(f"{filename}: unresolved datasource template {ds_uid!r}")
            elif ds_uid not in KNOWN_UIDS:
                errors.append(f"{filename}: unknown datasource uid {ds_uid!r}")

    return errors


def lint_files(directory):
    """Lint every ``.json`` dashboard in ``directory``.

    Returns ``(errors, linted)`` -- the problems found, and how many dashboards
    they were found in, which is what the caller's summary line counts against.
    An empty directory is itself a problem: every provisioning run renders at
    least one dashboard, so nothing there means something upstream broke quietly,
    and nothing else downstream would notice.
    """
    dashboards = {}
    for entry in os.listdir(directory):
        if not entry.endswith(".json"):
            continue
        dashboards[entry] = _load_json(os.path.join(directory, entry))

    if not dashboards:
        return [f"{directory}: no dashboards to lint"], 0
    # lint_dashboards sorts by filename itself, so os.listdir order is irrelevant.
    return lint_dashboards(dashboards), len(dashboards)


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    sanitize = subparsers.add_parser("sanitize", help="normalize exported dashboards")
    sanitize.add_argument("inputs", nargs="+", help="exported dashboard JSON files")
    sanitize.add_argument(
        "--out",
        required=True,
        metavar="DIR",
        help="directory to write sanitized dashboards into",
    )

    render = subparsers.add_parser("render", help="render dashboards from a spec")
    render.add_argument(
        "--spec", required=True, metavar="FILE", help="dashboard spec JSON from Nix"
    )
    render.add_argument(
        "--out", required=True, metavar="DIR", help="directory to write dashboards into"
    )

    lint = subparsers.add_parser("lint", help="validate a directory of dashboards")
    lint.add_argument(
        "directory", metavar="DIR", help="directory of dashboard JSON to validate"
    )
    return parser


def main():
    args = build_parser().parse_args()
    try:
        if args.command == "sanitize":
            return _sanitize(args)
        if args.command == "render":
            return _render(args)
        if args.command == "lint":
            return _lint(args)
    except (OSError, RuntimeError, ValueError) as error:
        # Same `grafana_dash: ` prefix the lint findings carry: one invocation can
        # emit both, and Nix interleaves every builder's output into one log.
        print(f"grafana_dash: error: {error}", file=sys.stderr)
        return 1
    raise RuntimeError(f"Unhandled command: {args.command}")


def _sanitize(args):
    sanitize_files(args.inputs, args.out)
    return 0


def _render(args):
    render_files(_load_json(args.spec), args.out)
    return 0


def _lint(args):
    errors, linted = lint_files(args.directory)
    for error in errors:
        print(f"grafana_dash: {error}", file=sys.stderr)
    if not errors:
        return 0
    # A trailing count is the line most likely to survive a truncated build log.
    print(
        f"grafana_dash: {len(errors)} problem(s) in {linted} dashboard(s)",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
