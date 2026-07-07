"""Pure logic for rankserver's stamp-watch and sort-state maintenance.

Stdlib-only; every function operates on plain data so it is unit-testable
without Flask or pysorting.

QuickSortState is represented as a dict with int keys
  sorted, n, top, p, i, j, l, c   (uint32 semantics; UINT32_MAX sentinel)
and list keys arr, stack.
"pos" values index into arr; values *of* arr index into file_map.
The stack holds flat (low, high) position pairs, valid up to index `top`
inclusive; the active partition is (stack[top-1], stack[top]).
"""
import re

UINT32_MAX = 0xFFFFFFFF
RANKABLE_EXTS = (".txt", ".png", ".mp4")
STAMP_RE = re.compile(r"stamped\.(.*?)\.")
# QuickSortState enum values (mirror sorting/Sorting.h); used by the
# sort-state surgery functions added alongside the QuickSortState helpers.
LEFT_J = 1
NOT_COMPARED = 0
CONFIG_NAME = "rank_config.json"


def is_rankable(name):
    return name.lower().endswith(RANKABLE_EXTS)


def stamp_prefix(tag):
    return "stamped.{}.".format(tag)


def scan_stamps(listing):
    """Map stamp tag -> count of rankable files carrying it, sorted by count desc."""
    tags = {}
    for f in listing:
        if not is_rankable(f):
            continue
        m = STAMP_RE.match(f)
        if m:
            tags[m.group(1)] = tags.get(m.group(1), 0) + 1
    return dict(sorted(tags.items(), key=lambda kv: kv[1], reverse=True))


def plan_sync(stamp_files, data_entries, tag):
    """Decide symlink operations to mirror tag-matching stamp files.

    stamp_files: iterable of filenames present in the watched stamp dir.
    data_entries: dict name -> entry describing the data-dir contents, where
        entry is {"type": "file"|"dir"|"symlink"} plus, for symlinks,
        "owned" (target's parent resolves into the watched stamp dir) and
        "dangling" (target no longer exists).
    Returns (to_link, to_prune, warnings): names to symlink into the data
    dir, owned dangling symlinks to remove, and human-readable warnings.
    Linking is scoped to the given tag, but pruning covers owned dangling
    symlinks of ANY tag: ownership is stamp-dir-based by design, so a file
    restamped to a different tag still gets its dead link cleaned up.
    Never proposes touching regular files, dirs, or foreign symlinks.
    """
    prefix = stamp_prefix(tag)
    to_link, to_prune, warnings = [], [], []
    for name in sorted(stamp_files):
        if not (name.startswith(prefix) and is_rankable(name)):
            continue
        entry = data_entries.get(name)
        if entry is None:
            to_link.append(name)
        elif entry["type"] == "file":
            warnings.append("Regular file blocks stamped name: {}".format(name))
    for name in sorted(data_entries):
        entry = data_entries[name]
        if entry["type"] == "symlink" and entry.get("owned") and entry.get("dangling"):
            to_prune.append(name)
    return to_link, to_prune, warnings
