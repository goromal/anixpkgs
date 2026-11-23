import os

import pytest

from aiart import projects


def test_create_find_record(tmp_path):
    p = projects.create(tmp_path, "castle", "3d", "a castle")
    assert projects.find(os.path.join(p.root, "out")).name == "castle"
    out = p.next_output("A Tall, Gothic Castle!", "glb")
    assert os.path.basename(out) == "001-a-tall-gothic-castle.glb"
    open(out, "w").close()
    p.record("mesh.gen", out, prompt="castle")
    assert os.readlink(os.path.join(p.root, "latest.glb")) == "out/001-a-tall-gothic-castle.glb"
    assert os.path.basename(p.next_output("x", "glb")).startswith("002-")
    assert p.journal()[0]["output"] == "out/001-a-tall-gothic-castle.glb"


def test_latest_link_replaced(tmp_path):
    p = projects.create(tmp_path, "art", "2d")
    for label in ("one", "two"):
        out = p.next_output(label, "png")
        open(out, "w").close()
        p.record("image.gen", out)
    assert os.readlink(os.path.join(p.root, "latest.png")).endswith("002-two.png")


def test_rejects_bad_names_and_duplicates(tmp_path):
    with pytest.raises(projects.ProjectError):
        projects.create(tmp_path, "../evil", "2d")
    with pytest.raises(projects.ProjectError):
        projects.create(tmp_path, "ok", "4d")
    projects.create(tmp_path, "ok", "2d")
    with pytest.raises(projects.ProjectError):
        projects.create(tmp_path, "ok", "2d")
    with pytest.raises(projects.ProjectError):
        projects.create(tmp_path, "ok", "2d", adopt=True)


def test_adopt_existing_work(tmp_path):
    (tmp_path / "Castle").mkdir()
    (tmp_path / "Castle" / "castle.glb").write_bytes(b"x")
    with pytest.raises(projects.ProjectError, match="--adopt"):
        projects.create(tmp_path, "Castle", "3d")
    p = projects.create(tmp_path, "Castle", "3d", adopt=True)
    assert p.kind == "3d" and (tmp_path / "Castle" / "castle.glb").read_bytes() == b"x"


def test_list_and_find_outside(tmp_path):
    projects.create(tmp_path, "a", "2d")
    projects.create(tmp_path, "b", "3d")
    (tmp_path / "stray").mkdir()
    assert sorted(p.name for p in projects.list_projects(tmp_path, tmp_path / "missing")) == ["a", "b"]
    assert projects.find(tmp_path / "stray") is None
