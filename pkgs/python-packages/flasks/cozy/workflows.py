import copy
import json
import math

# ---------------------------------------------------------------------------
# Resolution policies for "picky" models
# ---------------------------------------------------------------------------
# Some diffusion architectures are trained on a fixed set of resolution
# "buckets" clustered around a target pixel area. SDXL is the canonical example:
# ask it for an off-spec size -- too few pixels, or an aspect ratio outside the
# training set -- and it renders distorted anatomy and broken composition.
# Other models (z-image-turbo, Qwen-Image) are far more tolerant and need no
# help, so snapping must be opt-in per workflow rather than global.
#
# A workflow opts in by declaring a resolution policy in a top-level "_cozy" key
# in its <name>.api.json file:
#
#     {
#       "_cozy": {"resolution": "sdxl"},
#       "1": { ... ComfyUI nodes ... },
#       ...
#     }
#
# When present, the width/height a user types are snapped to the nearest bucket
# in the named set (matched by aspect ratio) before the graph is submitted. The
# "_cozy" key is cozy-only metadata: load_and_patch() strips it from the graph,
# so it never reaches ComfyUI's /prompt endpoint (which would reject a top-level
# key that is not a node).
#
# To support another picky model, add its bucket list to _RESOLUTION_BUCKETS
# under a new short name, then reference that name from the workflow's
# "_cozy.resolution". Workflows with no "_cozy" key are submitted with the exact
# dimensions requested -- flexible models pay no tax.

_RESOLUTION_BUCKETS = {
    # SDXL's standard training resolutions, each ~1.05 MP (the area SDXL was
    # trained at). From the SDXL technical report; applies to RealVisXL and
    # other SDXL fine-tunes.
    "sdxl": [
        (1024, 1024),
        (1152, 896),
        (896, 1152),
        (1216, 832),
        (832, 1216),
        (1344, 768),
        (768, 1344),
        (1536, 640),
        (640, 1536),
    ],
}


def snap_to_bucket(width, height, buckets):
    """Pick the bucket whose aspect ratio is closest to ``width/height``.

    Distance is measured on the log of the aspect ratio, so a request that is
    too tall is treated as exactly as far off as the mirror request that is too
    wide (e.g. 1:2 and 2:1 are equidistant from 1:1). The returned bucket's
    dimensions -- and therefore its pixel area, the model's native budget --
    replace whatever was asked for; that substitution is the entire point of
    snapping for resolution-sensitive models.
    """
    target = math.log(width / height)
    return min(buckets, key=lambda b: abs(math.log(b[0] / b[1]) - target))


def _find_prompt_node(graph):
    for nid, node in graph.items():
        meta = node.get("_meta") or {}
        if node.get("class_type") == "PrimitiveStringMultiline" and meta.get("title") == "Prompt":
            return nid
    for nid, node in graph.items():
        if node.get("class_type") == "PrimitiveStringMultiline":
            return nid
    return None


def _find_dimension_node(graph):
    for nid, node in graph.items():
        inputs = node.get("inputs") or {}
        if "width" in inputs and "height" in inputs:
            return nid
    return None


def _set_prompt_text(node, text):
    """Write user text into a node's text-bearing input (CLIPTextEncode uses
    'text', PrimitiveStringMultiline uses 'value')."""
    key = "text" if "text" in node.get("inputs", {}) else "value"
    node["inputs"][key] = text


def load_meta(path):
    """Return the cozy harness metadata for a workflow: {'kind': ...} plus any
    other _cozy keys. Defaults to the text-to-image 'generate' shape."""
    with open(path) as f:
        meta = (json.load(f).get("_cozy") or {})
    return {"kind": meta.get("kind", "generate"), **meta}


def load_and_patch(path, prompt, width, height, image=None):
    """Return ``(graph, width, height)``: a deep-copied API-format graph with the
    prompt and inputs injected, plus the dimensions actually applied.

    Behaviour depends on the workflow's _cozy.kind (default 'generate'):
      * generate: inject prompt into the PrimitiveStringMultiline 'Prompt' node
        and width/height into the dimension node, snapping dimensions if a
        resolution policy is declared.
      * edit: inject prompt text into _cozy.prompt_node and the input-image
        filename into _cozy.image_node (a LoadImage). Output size derives from
        the image, so width/height are not patched. Requires a non-empty image.

    The _cozy key is cozy-only metadata and is stripped from the returned graph.
    """
    with open(path) as f:
        graph = json.load(f)
    graph = copy.deepcopy(graph)
    width, height = int(width), int(height)

    cozy_meta = graph.pop("_cozy", None) or {}
    kind = cozy_meta.get("kind", "generate")

    if kind == "edit":
        if not image:
            raise ValueError("edit workflow requires an input image")
        _set_prompt_text(graph[cozy_meta["prompt_node"]], prompt)
        graph[cozy_meta["image_node"]]["inputs"]["image"] = image
        return graph, width, height

    policy = cozy_meta.get("resolution")
    if policy is not None:
        buckets = _RESOLUTION_BUCKETS.get(policy)
        if buckets is None:
            raise ValueError("unknown resolution policy: %r" % (policy,))
        width, height = snap_to_bucket(width, height, buckets)

    pnode = _find_prompt_node(graph)
    if pnode is None:
        raise ValueError("no prompt node (PrimitiveStringMultiline titled 'Prompt') found")
    graph[pnode]["inputs"]["value"] = prompt

    dnode = _find_dimension_node(graph)
    if dnode is None:
        raise ValueError("no width/height node found")
    graph[dnode]["inputs"]["width"] = width
    graph[dnode]["inputs"]["height"] = height

    return graph, width, height
