import copy
import json


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


def load_and_patch(path, prompt, width, height):
    """Return a deep-copied API-format graph with prompt + dimensions injected."""
    with open(path) as f:
        graph = json.load(f)
    graph = copy.deepcopy(graph)

    pnode = _find_prompt_node(graph)
    if pnode is None:
        raise ValueError("no prompt node (PrimitiveStringMultiline titled 'Prompt') found")
    graph[pnode]["inputs"]["value"] = prompt

    dnode = _find_dimension_node(graph)
    if dnode is None:
        raise ValueError("no width/height node found")
    graph[dnode]["inputs"]["width"] = int(width)
    graph[dnode]["inputs"]["height"] = int(height)

    return graph
