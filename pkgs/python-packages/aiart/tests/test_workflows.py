import json

import pytest
from PIL import Image

from aiart import ops, workflows


def test_bundled_mesh_workflow_is_consistent():
    meta, graph = workflows.load("hunyuan3d21")
    assert meta["kind"] == "mesh"
    assert graph[meta["image_node"]]["class_type"] == "LoadImage"
    assert graph[meta["save_node"]]["class_type"] == "SaveGLB"
    for node, field in meta["params"].values():
        assert field in graph[node]["inputs"]
    for node in graph.values():
        for value in node["inputs"].values():
            if isinstance(value, list):
                assert value[0] in graph


def test_patch_applies_and_validates():
    meta, graph = workflows.load("hunyuan3d21")
    g, applied = workflows.patch(meta, graph, "aiart/x.png", "aiart/mesh", {"steps": 12})
    assert g["2"]["inputs"]["image"] == "aiart/x.png"
    assert g["7"]["inputs"]["steps"] == 12
    assert isinstance(applied["seed"], int)
    assert graph["7"]["inputs"]["steps"] == 30
    with pytest.raises(workflows.WorkflowError):
        workflows.patch(meta, graph, "x", "p", {"nope": 1})


def test_extra_dir_overrides_bundled(tmp_path):
    custom = {"_aiart": {"kind": "mesh", "image_node": "1", "save_node": "2", "title": "mine"},
              "1": {"class_type": "LoadImage", "inputs": {"image": ""}},
              "2": {"class_type": "SaveGLB", "inputs": {"filename_prefix": ""}}}
    (tmp_path / "hunyuan3d21.api.json").write_text(json.dumps(custom))
    meta, _ = workflows.load("hunyuan3d21", [str(tmp_path)])
    assert meta["title"] == "mine"


def test_missing_models(tmp_path):
    meta, _ = workflows.load("hunyuan3d21")
    assert [m["name"] for m in workflows.missing_models(meta, tmp_path)] == [
        "hunyuan_3d_v2.1.safetensors", "birefnet.safetensors"]
    (tmp_path / "checkpoints").mkdir()
    (tmp_path / "checkpoints" / "hunyuan_3d_v2.1.safetensors").write_bytes(b"")
    assert [m["name"] for m in workflows.missing_models(meta, tmp_path)] == ["birefnet.safetensors"]


def test_flatten_composites_alpha_on_white(tmp_path):
    src = tmp_path / "a.png"
    Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(src)
    out = ops.flatten(str(src), str(tmp_path / "b.png"))
    with Image.open(out) as im:
        assert im.mode == "RGB" and im.getpixel((0, 0)) == (255, 255, 255)
