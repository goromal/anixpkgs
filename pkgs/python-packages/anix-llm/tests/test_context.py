import argparse
import json

from anix_llm.context import build_user_content, collect_context


def context_args(root, **overrides):
    values = {
        "context_dirs": [root],
        "include": [],
        "include_hidden": False,
        "max_context_files": 20,
        "max_context_bytes": 1_000,
        "max_context_file_bytes": 50,
    }
    values.update(overrides)
    return argparse.Namespace(**values)


def test_context_filters_unsafe_and_irrelevant_files(tmp_path):
    root = tmp_path / "project"
    root.mkdir()
    (root / "app.py").write_text("print('hello')\n")
    (root / "notes.txt").write_text("notes\n")
    (root / ".env").write_text("TOKEN=secret\n")
    (root / ".env.production").write_text("TOKEN=secret\n")
    (root / "binary.bin").write_bytes(b"text\x00binary")
    (root / "large.txt").write_text("x" * 100)
    (root / "node_modules").mkdir()
    (root / "node_modules" / "package.js").write_text("ignored\n")
    outside = tmp_path / "outside.txt"
    outside.write_text("outside\n")
    (root / "linked.txt").symlink_to(outside)

    context = collect_context(context_args(root))

    assert [item["path"] for item in context.directories[0]["files"]] == [
        "app.py",
        "notes.txt",
    ]
    assert context.skipped_count >= 5


def test_context_globs_and_json_boundaries(tmp_path):
    root = tmp_path / "project"
    root.mkdir()
    (root / "app.py").write_text("print('hello')\n")
    (root / "notes.txt").write_text("notes\n")

    context = collect_context(context_args(root, include=["*.py"]))
    encoded = json.loads(build_user_content("Summarize", context))

    assert encoded["task"] == "Summarize"
    assert encoded["directory_context"][0]["files"] == [
        {"path": "app.py", "content": "print('hello')\n"}
    ]
