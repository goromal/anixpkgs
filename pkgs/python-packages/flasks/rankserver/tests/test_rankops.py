import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import rankops


def test_scan_stamps_counts_rankable_only():
    listing = [
        "stamped.a.x.png", "stamped.a.y.mp4", "stamped.a.z.jpg",
        "stamped.b.q.txt", "plain.png", "file_map.log",
    ]
    result = rankops.scan_stamps(listing)
    assert result == {"a": 2, "b": 1}
    assert list(result.keys()) == ["a", "b"]  # sorted by count desc


def test_scan_stamps_empty():
    assert rankops.scan_stamps(["plain.png", "x.jpg"]) == {}


def test_plan_sync_links_missing_matches():
    to_link, to_prune, warns = rankops.plan_sync(
        ["stamped.t.a.png", "stamped.t.b.mp4", "stamped.u.c.png", "stamped.t.d.jpg"],
        {}, "t")
    assert to_link == ["stamped.t.a.png", "stamped.t.b.mp4"]
    assert to_prune == []
    assert warns == []


def test_plan_sync_skips_already_linked():
    entries = {"stamped.t.a.png": {"type": "symlink", "owned": True, "dangling": False}}
    to_link, to_prune, warns = rankops.plan_sync(["stamped.t.a.png"], entries, "t")
    assert to_link == [] and to_prune == [] and warns == []


def test_plan_sync_prunes_owned_dangling_only():
    entries = {
        "stamped.t.a.png": {"type": "symlink", "owned": True, "dangling": True},
        "stamped.t.b.png": {"type": "symlink", "owned": True, "dangling": False},
        "foreign.png": {"type": "symlink", "owned": False, "dangling": True},
        "regular.png": {"type": "file"},
        "somedir": {"type": "dir"},
    }
    to_link, to_prune, warns = rankops.plan_sync([], entries, "t")
    assert to_prune == ["stamped.t.a.png"]
    assert to_link == [] and warns == []


def test_plan_sync_prunes_owned_dangling_across_tags():
    # Ownership is stamp-dir-based, not tag-based: a dangling link left by a
    # different (or former) tag is still cleaned up.
    entries = {"stamped.other.x.png": {"type": "symlink", "owned": True, "dangling": True}}
    to_link, to_prune, warns = rankops.plan_sync([], entries, "t")
    assert to_prune == ["stamped.other.x.png"]


def test_plan_sync_warns_on_blocking_regular_file():
    entries = {"stamped.t.a.png": {"type": "file"}}
    to_link, to_prune, warns = rankops.plan_sync(["stamped.t.a.png"], entries, "t")
    assert to_link == []
    assert len(warns) == 1 and "stamped.t.a.png" in warns[0]
