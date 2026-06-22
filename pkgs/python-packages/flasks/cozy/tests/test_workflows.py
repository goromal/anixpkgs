import json
import os

import pytest

import workflows

FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "imggen.api.json")


def test_patch_injects_prompt_and_dimensions():
    graph = workflows.load_and_patch(FIXTURE, "a red bicycle", 400, 800)
    prompt_nodes = [
        n for n in graph.values()
        if n.get("class_type") == "PrimitiveStringMultiline"
        and (n.get("_meta") or {}).get("title") == "Prompt"
    ]
    assert len(prompt_nodes) == 1
    assert prompt_nodes[0]["inputs"]["value"] == "a red bicycle"
    dim_nodes = [
        n for n in graph.values()
        if "width" in n.get("inputs", {}) and "height" in n.get("inputs", {})
    ]
    assert len(dim_nodes) == 1
    assert dim_nodes[0]["inputs"]["width"] == 400
    assert dim_nodes[0]["inputs"]["height"] == 800


def test_patch_does_not_mutate_file():
    before = open(FIXTURE).read()
    workflows.load_and_patch(FIXTURE, "x", 100, 100)
    assert open(FIXTURE).read() == before


def test_missing_prompt_node_raises(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({"1": {"class_type": "Foo", "inputs": {}}}))
    with pytest.raises(ValueError):
        workflows.load_and_patch(str(bad), "x", 100, 100)


def test_missing_dimension_node_raises(tmp_path):
    bad = tmp_path / "bad.json"
    bad.write_text(json.dumps({
        "1": {"class_type": "PrimitiveStringMultiline",
              "_meta": {"title": "Prompt"}, "inputs": {"value": ""}}
    }))
    with pytest.raises(ValueError):
        workflows.load_and_patch(str(bad), "x", 100, 100)
