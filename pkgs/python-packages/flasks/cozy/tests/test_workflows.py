import json
import os

import pytest

import workflows

FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "imggen.api.json")


def test_patch_injects_prompt_and_dimensions():
    graph, width, height = workflows.load_and_patch(FIXTURE, "a red bicycle", 400, 800)
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
    # A workflow with no resolution policy keeps the exact requested size.
    assert (width, height) == (400, 800)


def test_patch_does_not_mutate_file():
    before = open(FIXTURE).read()
    workflows.load_and_patch(FIXTURE, "x", 100, 100)
    assert open(FIXTURE).read() == before


def _sdxl_graph():
    """Minimal SDXL-style API graph that opts into the 'sdxl' resolution policy."""
    return {
        "_cozy": {"resolution": "sdxl"},
        "1": {"class_type": "PrimitiveStringMultiline",
              "_meta": {"title": "Prompt"}, "inputs": {"value": ""}},
        "2": {"class_type": "EmptyLatentImage",
              "inputs": {"width": 0, "height": 0, "batch_size": 1}},
    }


def test_snap_to_bucket_matches_nearest_aspect():
    sdxl = workflows._RESOLUTION_BUCKETS["sdxl"]
    assert workflows.snap_to_bucket(500, 500, sdxl) == (1024, 1024)
    # 1:2 portrait snaps to the closest tall bucket (768x1344, aspect ~0.57)...
    assert workflows.snap_to_bucket(400, 800, sdxl) == (768, 1344)
    # ...and its mirror lands on the mirror bucket.
    assert workflows.snap_to_bucket(800, 400, sdxl) == (1344, 768)


def test_resolution_policy_snaps_and_strips_meta(tmp_path):
    p = tmp_path / "sdxl.api.json"
    p.write_text(json.dumps(_sdxl_graph()))
    graph, width, height = workflows.load_and_patch(str(p), "a face", 400, 800)
    assert (width, height) == (768, 1344)
    assert graph["2"]["inputs"]["width"] == 768
    assert graph["2"]["inputs"]["height"] == 1344
    # cozy-only metadata must never reach ComfyUI's /prompt endpoint.
    assert "_cozy" not in graph


def test_unknown_resolution_policy_raises(tmp_path):
    g = _sdxl_graph()
    g["_cozy"]["resolution"] = "bogus"
    p = tmp_path / "bad.api.json"
    p.write_text(json.dumps(g))
    with pytest.raises(ValueError):
        workflows.load_and_patch(str(p), "x", 100, 100)


def test_no_policy_keeps_exact_dimensions(tmp_path):
    g = _sdxl_graph()
    del g["_cozy"]
    p = tmp_path / "free.api.json"
    p.write_text(json.dumps(g))
    graph, width, height = workflows.load_and_patch(str(p), "x", 333, 777)
    assert (width, height) == (333, 777)
    assert graph["2"]["inputs"]["width"] == 333
    assert graph["2"]["inputs"]["height"] == 777


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


def _edit_graph():
    return {
        "_cozy": {"kind": "edit", "prompt_node": "5", "image_node": "1"},
        "1": {"class_type": "LoadImage", "inputs": {"image": "old.png"}},
        "5": {"class_type": "CLIPTextEncode",
              "_meta": {"title": "CLIP Text Encode (Edit Instruction)"},
              "inputs": {"text": "", "clip": ["3", 0]}},
        "6": {"class_type": "CLIPTextEncode", "inputs": {"text": "neg", "clip": ["3", 0]}},
    }


def test_edit_patch_sets_text_and_image(tmp_path):
    p = tmp_path / "imgedit.api.json"
    p.write_text(json.dumps(_edit_graph()))
    graph, w, h = workflows.load_and_patch(str(p), "add a hat", 400, 800, image="me.png")
    assert graph["5"]["inputs"]["text"] == "add a hat"
    assert graph["1"]["inputs"]["image"] == "me.png"
    assert "_cozy" not in graph
    assert graph["6"]["inputs"]["text"] == "neg"


def test_edit_patch_requires_image(tmp_path):
    p = tmp_path / "imgedit.api.json"
    p.write_text(json.dumps(_edit_graph()))
    with pytest.raises(ValueError):
        workflows.load_and_patch(str(p), "add a hat", 400, 800, image="")


def test_load_meta_returns_kind(tmp_path):
    p = tmp_path / "imgedit.api.json"
    p.write_text(json.dumps(_edit_graph()))
    assert workflows.load_meta(str(p))["kind"] == "edit"
    p2 = tmp_path / "plain.api.json"
    p2.write_text(json.dumps({"1": {"class_type": "Foo", "inputs": {}}}))
    assert workflows.load_meta(str(p2))["kind"] == "generate"
