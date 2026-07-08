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


def test_get_watches_normalizes_legacy_and_list():
    assert rankops.get_watches({}) == []
    assert rankops.get_watches({"watch": None}) == []
    legacy = {"watch": {"stamp_dir": "/s", "stamp_tag": "t"}}
    assert rankops.get_watches(legacy) == [{"stamp_dir": "/s", "stamp_tag": "t"}]
    multi = {"watches": [{"stamp_dir": "/a", "stamp_tag": "x"},
                         {"stamp_dir": "/b", "stamp_tag": "y"}]}
    assert rankops.get_watches(multi) == multi["watches"]
    # "watches" takes precedence over a stale legacy key; junk entries dropped
    both = {"watches": [{"stamp_dir": "/a", "stamp_tag": "x"}, "junk"],
            "watch": {"stamp_dir": "/old", "stamp_tag": "z"}}
    assert rankops.get_watches(both) == [{"stamp_dir": "/a", "stamp_tag": "x"}]


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


UMAX = rankops.UINT32_MAX


def _mid_state():
    # n=6; pending ranges (0,2) and active (4,5); positions 3 is final.
    # Fresh active partition: p=high=5, i=low-1=3, j=low=4, l=J(1), c=0.
    return (
        {"sorted": 0, "n": 6, "arr": [5, 2, 0, 1, 3, 4],
         "stack": [0, 2, 4, 5, 0, 0], "top": 3,
         "p": 5, "i": 3, "j": 4, "l": 1, "c": 0},
        ["f0", "f1", "f2", "f3", "f4", "f5"],
    )


def test_remove_outside_active_preserves_progress():
    state, fmap = _mid_state()
    # remove pos=1 (arr[1] == 2 -> file f2): inside pending (0,2), not active
    s2, m2, restarted = rankops.remove_index(state, fmap, 2)
    assert not restarted
    assert m2 == ["f0", "f1", "f3", "f4", "f5"]
    assert s2["n"] == 5
    assert s2["arr"] == [4, 0, 1, 2, 3]          # popped pos1, values >2 shifted
    assert s2["stack"][:4] == [0, 1, 3, 4]        # (0,2)->(0,1), (4,5)->(3,4)
    assert s2["top"] == 3
    assert (s2["p"], s2["i"], s2["j"]) == (4, 2, 3)  # cursors shifted with range
    assert (s2["l"], s2["c"]) == (1, 0)              # comparator handshake kept
    assert len(s2["stack"]) == 5
    # inputs untouched (contents, not just sizes)
    assert state["arr"] == [5, 2, 0, 1, 3, 4]
    assert state["stack"] == [0, 2, 4, 5, 0, 0]
    assert state["n"] == 6
    assert fmap == ["f0", "f1", "f2", "f3", "f4", "f5"]


def test_remove_finalized_element_preserves_progress():
    state, fmap = _mid_state()
    # k=1 -> pos=3: outside pending (0,2) AND active (4,5) (a finalized
    # position). Exercises the m == 0 branch of the cursor restore.
    s2, m2, restarted = rankops.remove_index(state, fmap, 1)
    assert not restarted
    assert m2 == ["f0", "f2", "f3", "f4", "f5"]
    assert s2["arr"] == [4, 1, 0, 2, 3]
    assert s2["stack"][:4] == [0, 2, 3, 4] and s2["top"] == 3
    assert (s2["p"], s2["i"], s2["j"]) == (4, 2, 3)
    assert (s2["l"], s2["c"]) == (1, 0)


def test_remove_inside_active_restarts_partition_only():
    state, fmap = _mid_state()
    # remove pos=4 (arr[4] == 3 -> f3): inside active (4,5) -> pair drops to
    # singleton, next pair (0,2) becomes active and is restarted.
    s2, m2, restarted = rankops.remove_index(state, fmap, 3)
    assert restarted
    assert s2["n"] == 5
    assert s2["arr"] == [4, 2, 0, 1, 3]
    assert s2["stack"][:2] == [0, 2] and s2["top"] == 1
    assert (s2["p"], s2["i"], s2["j"]) == (2, UMAX, 0)  # resetPartition, low==0 wrap
    assert (s2["l"], s2["c"]) == (1, 0)
    assert s2["sorted"] == 0


def test_remove_last_pending_pair_completes_sort():
    # k=0 puts the removal at the active range's HIGH boundary (pos == high),
    # exercising the high >= pos shift rule.
    state = {"sorted": 0, "n": 2, "arr": [1, 0], "stack": [0, 1], "top": 1,
             "p": 1, "i": UMAX, "j": 0, "l": 1, "c": 0}
    s2, m2, restarted = rankops.remove_index(state, ["a", "b"], 0)
    assert s2["sorted"] == 1
    assert s2["n"] == 1 and s2["arr"] == [0] and m2 == ["b"]
    assert s2["top"] == UMAX
    assert not restarted  # sort completed; no comparisons were discarded


def test_remove_from_sorted_state():
    state = {"sorted": 1, "n": 3, "arr": [2, 0, 1], "stack": [0, 0, 0],
             "top": UMAX, "p": 0, "i": 0, "j": 0, "l": 1, "c": 0}
    s2, m2, restarted = rankops.remove_index(state, ["a", "b", "c"], 0)
    assert not restarted
    assert s2["sorted"] == 1 and s2["n"] == 2
    assert s2["arr"] == [1, 0] and m2 == ["b", "c"]
    assert s2["stack"] == [0, 0] and s2["top"] == UMAX


def test_validate_accepts_produced_states():
    state, fmap = _mid_state()
    ok, msg = rankops.validate_state(state, fmap)
    assert ok, msg
    for k in (2, 3):
        s2, m2, _ = rankops.remove_index(state, fmap, k)
        ok, msg = rankops.validate_state(s2, m2)
        assert ok, msg


def test_validate_rejects_malformed():
    state, fmap = _mid_state()
    bad = dict(state, arr=[0, 0, 1, 2, 3, 4])
    assert not rankops.validate_state(bad, fmap)[0]
    bad = dict(state, sorted=1)                      # sorted but top != UMAX
    assert not rankops.validate_state(bad, fmap)[0]
    bad = dict(state, p=4)                           # pivot not at range high
    assert not rankops.validate_state(bad, fmap)[0]
    assert not rankops.validate_state(state, fmap[:-1])[0]  # map length mismatch


def _sorted_state():
    return (
        {"sorted": 1, "n": 4, "arr": [3, 1, 0, 2], "stack": [0, 0, 0, 0],
         "top": UMAX, "p": 0, "i": 0, "j": 0, "l": 1, "c": 0},
        ["f0", "f1", "f2", "f3"],
    )


def _no_insertions():
    return {"queue": [], "active": None}


def test_reconcile_queues_new_files_sorted():
    state, fmap = _sorted_state()
    present = set(fmap) | {"new_b.png", "new_a.png"}
    s2, m2, ins2, res = rankops.reconcile(state, fmap, present, _no_insertions())
    assert ins2["queue"] == ["new_a.png", "new_b.png"]
    assert not res["changed"] and not res["reset_all"]
    assert m2 == fmap


def test_reconcile_dedupes_known_files():
    state, fmap = _sorted_state()
    ins = {"queue": ["q.png"], "active": {"file": "a.png", "lo": 1, "hi": 3}}
    present = set(fmap) | {"q.png", "a.png"}
    s2, m2, ins2, res = rankops.reconcile(state, fmap, present, ins)
    assert ins2["queue"] == ["q.png"]
    assert ins2["active"]["file"] == "a.png"


def test_reconcile_removes_missing_and_shifts_active_bounds():
    state, fmap = _sorted_state()
    ins = {"queue": [], "active": {"file": "a.png", "lo": 2, "hi": 4}}
    present = (set(fmap) - {"f1"}) | {"a.png"}   # f1 sits at arr pos 1
    s2, m2, ins2, res = rankops.reconcile(state, fmap, present, ins)
    assert res["changed"] and not res["reset_all"]
    assert m2 == ["f0", "f2", "f3"]
    assert s2["n"] == 3
    assert ins2["active"] == {"file": "a.png", "lo": 1, "hi": 3}
    ok, msg = rankops.validate_state(s2, m2)
    assert ok, msg


def test_reconcile_mid_sort_removal_counts_restart_and_shifts_bounds():
    state, fmap = _mid_state()
    # f3 sits inside the active partition (arr pos 4): its removal restarts
    # that partition; the active insertion's bounds shift past pos 4.
    ins = {"queue": [], "active": {"file": "a.png", "lo": 5, "hi": 6}}
    present = (set(fmap) - {"f3"}) | {"a.png"}
    s2, m2, ins2, res = rankops.reconcile(state, fmap, present, ins)
    assert res["changed"] and res["partitions_restarted"] == 1
    assert m2 == ["f0", "f1", "f2", "f4", "f5"]
    assert ins2["active"] == {"file": "a.png", "lo": 4, "hi": 5}
    assert ins == {"queue": [], "active": {"file": "a.png", "lo": 5, "hi": 6}}
    ok, msg = rankops.validate_state(s2, m2)
    assert ok, msg


def test_reconcile_drops_vanished_queue_and_active():
    state, fmap = _sorted_state()
    ins = {"queue": ["gone.png"], "active": {"file": "also_gone.png", "lo": 0, "hi": 4}}
    s2, m2, ins2, res = rankops.reconcile(state, fmap, set(fmap), ins)
    assert ins2 == {"queue": [], "active": None}


def test_reconcile_reset_all_when_settled_set_empties():
    state = {"sorted": 1, "n": 1, "arr": [0], "stack": [0], "top": UMAX,
             "p": 0, "i": 0, "j": 0, "l": 1, "c": 0}
    s2, m2, ins2, res = rankops.reconcile(state, ["only.png"], {"other.png"},
                                          _no_insertions())
    assert res["reset_all"]
    assert m2 == [] and ins2 == {"queue": [], "active": None}


def test_insertion_binary_search_converges_high():
    b = {"lo": 0, "hi": 4}
    while not rankops.insertion_done(b):
        b = rankops.insertion_step(b, prefer_new=True)
    assert b["lo"] == 4  # always preferred -> inserts at the top


def test_insertion_binary_search_converges_low():
    b = {"lo": 0, "hi": 4}
    while not rankops.insertion_done(b):
        b = rankops.insertion_step(b, prefer_new=False)
    assert b["lo"] == 0


def test_insertion_step_moves_correct_bound():
    b = rankops.insertion_step({"lo": 0, "hi": 5}, prefer_new=True)
    assert b == {"lo": 3, "hi": 5}   # mid=2, new preferred -> after mid
    b = rankops.insertion_step({"lo": 0, "hi": 5}, prefer_new=False)
    assert b == {"lo": 0, "hi": 2}


def test_insertion_complete_places_file():
    state, fmap = _sorted_state()
    s2, m2 = rankops.insertion_complete(state, fmap, "new.png", 2)
    assert m2 == ["f0", "f1", "f2", "f3", "new.png"]
    assert s2["arr"] == [3, 1, 4, 0, 2]   # new index 4 spliced at pos 2
    assert s2["n"] == 5 and len(s2["stack"]) == 5 and s2["top"] == UMAX
    ok, msg = rankops.validate_state(s2, m2)
    assert ok, msg
