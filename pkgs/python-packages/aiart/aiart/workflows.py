"""Mesh workflows: API-format ComfyUI graphs with an `_aiart` header.

Bundled graphs live next to this module; config `workflowDirs` adds more, and
a later directory wins on a name clash, which is how a newer model replaces a
bundled one without a rebuild. See README.md for the header fields.
"""
import copy
import json
import os
import random

BUNDLED = os.path.join(os.path.dirname(__file__), "workflows")
SUFFIX = ".api.json"


class WorkflowError(Exception):
    pass


def available(extra_dirs=()):
    found = {}
    for d in [BUNDLED, *[os.path.expanduser(x) for x in extra_dirs]]:
        if not os.path.isdir(d):
            continue
        for n in sorted(os.listdir(d)):
            if n.endswith(SUFFIX):
                found[n[:-len(SUFFIX)]] = os.path.join(d, n)
    return found


def load(name, extra_dirs=()):
    path = available(extra_dirs).get(name)
    if not path:
        raise WorkflowError("no mesh workflow named %r" % name)
    with open(path) as f:
        graph = json.load(f)
    meta = graph.pop("_aiart", None)
    if not meta:
        raise WorkflowError("%s has no _aiart header" % path)
    return meta, graph


def patch(meta, graph, image, prefix, params=None):
    """Return a copy of `graph` with the input image, output prefix and any
    named tunables applied. Unknown tunables are an error, not a no-op."""
    g = copy.deepcopy(graph)
    g[meta["image_node"]]["inputs"]["image"] = image
    g[meta["save_node"]]["inputs"]["filename_prefix"] = prefix
    table = meta.get("params", {})
    params = dict(params or {})
    if "seed" in table and params.get("seed") is None:
        params["seed"] = random.randint(0, 2**32 - 1)
    for key, value in params.items():
        if value is None:
            continue
        if key not in table:
            raise WorkflowError("workflow has no tunable %r (has: %s)" % (
                key, ", ".join(sorted(table))))
        node, field = table[key]
        g[node]["inputs"][field] = value
    return g, params


def missing_models(meta, models_dir):
    out = []
    for m in meta.get("models", []):
        if not os.path.exists(os.path.join(models_dir, m["dir"], m["name"])):
            out.append(m)
    return out
