import argparse

import pytest

from anix_llm.files import confirm_and_write, parse_manifest, validate_files


def test_manifest_writes_beneath_output_directory(tmp_path):
    output_dir = tmp_path / "output"
    manifest = parse_manifest(
        '{"files":[{"path":"docs/start.md","content":"hello\\n"}]}'
    )
    files = validate_files(
        manifest,
        output_dir,
        max_files=10,
        max_bytes=1_000,
        overwrite=False,
    )
    confirm_and_write(files, output_dir, overwrite=False, assume_yes=True)

    assert (output_dir / "docs/start.md").read_text() == "hello\n"


@pytest.mark.parametrize("unsafe_path", ["../escape.txt", "/tmp/escape.txt"])
def test_manifest_rejects_path_escape(tmp_path, unsafe_path):
    with pytest.raises(RuntimeError):
        validate_files(
            {"files": [{"path": unsafe_path, "content": "bad"}]},
            tmp_path / "output",
            max_files=10,
            max_bytes=1_000,
            overwrite=False,
        )


def test_manifest_rejects_symlink_escape(tmp_path):
    output_dir = tmp_path / "output"
    outside = tmp_path / "outside"
    output_dir.mkdir()
    outside.mkdir()
    (output_dir / "link").symlink_to(outside, target_is_directory=True)

    with pytest.raises(RuntimeError, match="escapes"):
        validate_files(
            {"files": [{"path": "link/escape.txt", "content": "bad"}]},
            output_dir,
            max_files=10,
            max_bytes=1_000,
            overwrite=False,
        )
