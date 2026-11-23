"""Project directories.

A project is a directory holding project.json, refs/ (user-supplied inputs),
out/ (every generated artifact, numbered) and journal.jsonl (one line per
generation, so an agent can resume where an earlier session stopped).
`latest.<ext>` always links to the newest output of that type, so a viewer
pointed at it follows along.
"""
import datetime
import json
import os
import re

KINDS = ("2d", "3d")
_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
MARKER = "project.json"


class ProjectError(Exception):
    pass


def _now():
    return datetime.datetime.now().isoformat(timespec="seconds")


def slug(text, limit=40):
    s = re.sub(r"[^A-Za-z0-9]+", "-", text or "").strip("-").lower()
    return s[:limit].rstrip("-") or "out"


class Project:
    def __init__(self, root):
        self.root = os.path.abspath(root)
        with open(os.path.join(self.root, MARKER)) as f:
            self.meta = json.load(f)

    @property
    def name(self):
        return self.meta["name"]

    @property
    def kind(self):
        return self.meta["kind"]

    @property
    def out_dir(self):
        return os.path.join(self.root, "out")

    @property
    def refs_dir(self):
        return os.path.join(self.root, "refs")

    def journal(self):
        path = os.path.join(self.root, "journal.jsonl")
        if not os.path.exists(path):
            return []
        with open(path) as f:
            return [json.loads(line) for line in f if line.strip()]

    def next_output(self, label, ext):
        os.makedirs(self.out_dir, exist_ok=True)
        nums = [int(m.group(1)) for m in
                (re.match(r"^(\d+)-", n) for n in os.listdir(self.out_dir)) if m]
        n = max(nums, default=0) + 1
        return os.path.join(self.out_dir, "%03d-%s.%s" % (n, slug(label), ext))

    def record(self, action, output, **details):
        entry = {"at": _now(), "action": action,
                 "output": os.path.relpath(output, self.root), **details}
        with open(os.path.join(self.root, "journal.jsonl"), "a") as f:
            f.write(json.dumps(entry) + "\n")
        ext = os.path.splitext(output)[1]
        link = os.path.join(self.root, "latest" + ext)
        tmp = link + ".tmp"
        if os.path.lexists(tmp):
            os.remove(tmp)
        os.symlink(os.path.relpath(output, self.root), tmp)
        os.replace(tmp, link)
        return entry

    def modified(self):
        path = os.path.join(self.root, "journal.jsonl")
        target = path if os.path.exists(path) else os.path.join(self.root, MARKER)
        return os.path.getmtime(target)


def create(projects_dir, name, kind, description=""):
    if not _NAME_RE.match(name or ""):
        raise ProjectError("project names use letters, digits, '.', '_' and '-'")
    if kind not in KINDS:
        raise ProjectError("kind must be one of %s" % ", ".join(KINDS))
    root = os.path.join(os.path.expanduser(projects_dir), name)
    if os.path.exists(root):
        raise ProjectError("%s already exists" % root)
    for sub in ("refs", "out"):
        os.makedirs(os.path.join(root, sub))
    meta = {"name": name, "kind": kind, "description": description,
            "created": _now()}
    with open(os.path.join(root, MARKER), "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    return Project(root)


def list_projects(projects_dir):
    base = os.path.expanduser(projects_dir)
    if not os.path.isdir(base):
        return []
    found = [Project(os.path.join(base, n)) for n in os.listdir(base)
             if os.path.isfile(os.path.join(base, n, MARKER))]
    return sorted(found, key=lambda p: p.modified(), reverse=True)


def find(start=None):
    """The project containing `start` (default: cwd), or None."""
    path = os.path.abspath(start or os.getcwd())
    while True:
        if os.path.isfile(os.path.join(path, MARKER)):
            return Project(path)
        parent = os.path.dirname(path)
        if parent == path:
            return None
        path = parent
