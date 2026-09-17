"""Validate and write an LLM-generated text-file manifest."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any


FILE_MANIFEST_SCHEMA = {
    "type": "object",
    "properties": {
        "files": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "path": {"type": "string", "minLength": 1},
                    "content": {"type": "string"},
                },
                "required": ["path", "content"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["files"],
    "additionalProperties": False,
}

RESPONSE_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "file_manifest",
        "strict": True,
        "schema": FILE_MANIFEST_SCHEMA,
    },
}


def parse_manifest(content: str) -> dict[str, Any]:
    candidate = content.strip()
    if candidate.startswith("```"):
        lines = candidate.splitlines()
        if len(lines) >= 3 and lines[-1].strip() == "```":
            candidate = "\n".join(lines[1:-1])
    try:
        manifest = json.loads(candidate)
    except json.JSONDecodeError as error:
        raise RuntimeError(f"The LLM did not return valid JSON: {error}") from error
    if not isinstance(manifest, dict) or set(manifest) != {"files"}:
        raise RuntimeError("Manifest must be an object containing only 'files'")
    if not isinstance(manifest["files"], list):
        raise RuntimeError("Manifest 'files' must be a list")
    return manifest


def validate_files(
    manifest: dict[str, Any],
    output_dir: Path,
    *,
    max_files: int,
    max_bytes: int,
    overwrite: bool,
) -> list[tuple[Path, str]]:
    root = output_dir.resolve()
    files = manifest["files"]
    if len(files) > max_files:
        raise RuntimeError(f"Manifest has {len(files)} files; limit is {max_files}")

    validated: list[tuple[Path, str]] = []
    seen: set[Path] = set()
    total_bytes = 0
    for index, item in enumerate(files):
        if not isinstance(item, dict) or set(item) != {"path", "content"}:
            raise RuntimeError(f"File {index} must contain only 'path' and 'content'")
        relative_name = item["path"]
        content = item["content"]
        if not isinstance(relative_name, str) or not relative_name.strip():
            raise RuntimeError(f"File {index} has an invalid path")
        if not isinstance(content, str):
            raise RuntimeError(f"File {relative_name!r} has non-text content")
        if "\\" in relative_name or "\x00" in relative_name:
            raise RuntimeError(f"Unsafe path rejected: {relative_name!r}")

        relative_path = Path(relative_name)
        if relative_path.is_absolute() or ".." in relative_path.parts:
            raise RuntimeError(f"Unsafe path rejected: {relative_name!r}")
        target = (root / relative_path).resolve()
        if not target.is_relative_to(root) or target == root:
            raise RuntimeError(f"Path escapes output directory: {relative_name!r}")
        if target in seen:
            raise RuntimeError(f"Duplicate output path: {relative_name!r}")
        if target.exists() and not overwrite:
            raise RuntimeError(f"Refusing to overwrite existing path: {target}")
        if target.exists() and not target.is_file():
            raise RuntimeError(f"Output path is not a regular file: {target}")

        seen.add(target)
        total_bytes += len(content.encode("utf-8"))
        validated.append((target, content))

    if total_bytes > max_bytes:
        raise RuntimeError(f"Output is {total_bytes} bytes; limit is {max_bytes}")
    return validated


def confirm_and_write(
    files: list[tuple[Path, str]],
    output_dir: Path,
    *,
    overwrite: bool,
    assume_yes: bool,
) -> None:
    total_bytes = sum(len(content.encode("utf-8")) for _, content in files)
    print(f"LLM proposed {len(files)} file(s), {total_bytes} UTF-8 bytes:")
    for target, content in files:
        print(f"  {target} ({len(content.encode('utf-8'))} bytes)")

    if not assume_yes:
        if not sys.stdin.isatty():
            raise RuntimeError("Confirmation requires a terminal; use --yes to approve")
        if input("Write these files? [y/N] ").strip().lower() not in {"y", "yes"}:
            print("No files written.")
            return

    for target, content in files:
        target.parent.mkdir(parents=True, exist_ok=True)
        mode = "w" if overwrite else "x"
        with target.open(mode, encoding="utf-8", newline="") as output_file:
            output_file.write(content)
    print(f"Wrote {len(files)} file(s) beneath {output_dir.resolve()}")
