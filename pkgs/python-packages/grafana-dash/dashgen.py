"""Generate, sanitize, and lint Grafana dashboards for anixpkgs metricsNode."""

import argparse
import copy
import json
import os
import sys

PROM_UID = "anix-prometheus"
LOKI_UID = "anix-loki"

# Datasource uids that are legal in provisioned output.
BUILTIN_UIDS = {"grafana", "-- Grafana --"}
KNOWN_UIDS = {PROM_UID, LOKI_UID} | BUILTIN_UIDS

_TYPE_TO_UID = {"prometheus": PROM_UID, "loki": LOKI_UID}

# Keys that only mean something to the interactive importer.
_IMPORT_ONLY_KEYS = ("__inputs", "__elements", "__requires")


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
        with open(path) as f:
            dashboard = json.load(f)
        with open(os.path.join(out_dir, name), "w") as f:
            json.dump(sanitize_dashboard(dashboard), f, indent=2, sort_keys=True)


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
    return parser


def main():
    args = build_parser().parse_args()
    try:
        if args.command == "sanitize":
            return _sanitize(args)
    except (OSError, RuntimeError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    raise RuntimeError(f"Unhandled command: {args.command}")


def _sanitize(args):
    sanitize_files(args.inputs, args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
