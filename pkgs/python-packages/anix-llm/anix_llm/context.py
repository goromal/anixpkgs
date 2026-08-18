"""Collect bounded, text-only directory context for local LLM prompts."""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any


EXCLUDED_DIRECTORIES = {
    ".git",
    ".hg",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".svn",
    ".tox",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "node_modules",
    "target",
    "vendor",
}

SENSITIVE_NAMES = {
    ".env",
    ".npmrc",
    ".pypirc",
    "credentials.json",
    "id_ed25519",
    "id_rsa",
    "secrets.json",
}

SENSITIVE_SUFFIXES = {".key", ".p12", ".pem", ".pfx"}


@dataclass(frozen=True)
class DirectoryContext:
    directories: list[dict[str, Any]]
    file_count: int
    byte_count: int
    skipped_count: int


def add_context_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--context",
        "--context-dir",
        action="append",
        default=[],
        dest="context_dirs",
        type=Path,
        metavar="PATH",
        help="Recursively add a directory as model context; may be repeated",
    )
    parser.add_argument(
        "--include",
        action="append",
        default=[],
        metavar="GLOB",
        help="Include only matching context paths, such as '*.py' or 'src/**'",
    )
    parser.add_argument(
        "--include-hidden",
        action="store_true",
        help="Include hidden files except common secrets and keys",
    )
    parser.add_argument("--max-context-files", type=int, default=200)
    parser.add_argument("--max-context-bytes", type=int, default=60_000)
    parser.add_argument("--max-context-file-bytes", type=int, default=30_000)


def collect_context(args: argparse.Namespace) -> DirectoryContext:
    if not args.context_dirs:
        return DirectoryContext([], 0, 0, 0)
    for option in (
        "max_context_files",
        "max_context_bytes",
        "max_context_file_bytes",
    ):
        if getattr(args, option) <= 0:
            raise ValueError(f"--{option.replace('_', '-')} must be positive")

    directories: list[dict[str, Any]] = []
    file_count = 0
    byte_count = 0
    skipped_count = 0

    for requested_root in args.context_dirs:
        root = requested_root.resolve()
        if not root.is_dir():
            raise ValueError(f"Context directory does not exist: {requested_root}")
        collected_files: list[dict[str, str]] = []

        for current_directory, child_directories, file_names in os.walk(
            root, followlinks=False
        ):
            current_path = Path(current_directory)
            child_directories[:] = sorted(
                directory
                for directory in child_directories
                if _include_directory(current_path / directory, directory, args)
            )

            for file_name in sorted(file_names):
                path = current_path / file_name
                relative_name = path.relative_to(root).as_posix()

                if file_count >= args.max_context_files:
                    skipped_count += 1
                    continue
                if not _include_file(path, relative_name, args):
                    skipped_count += 1
                    continue

                try:
                    size = path.stat().st_size
                except OSError:
                    skipped_count += 1
                    continue
                if size > args.max_context_file_bytes:
                    skipped_count += 1
                    continue
                if byte_count + size > args.max_context_bytes:
                    skipped_count += 1
                    continue

                try:
                    raw_content = path.read_bytes()
                    if b"\x00" in raw_content:
                        raise UnicodeError("NUL byte")
                    content = raw_content.decode("utf-8")
                except (OSError, UnicodeError):
                    skipped_count += 1
                    continue

                actual_size = len(raw_content)
                if byte_count + actual_size > args.max_context_bytes:
                    skipped_count += 1
                    continue
                collected_files.append({"path": relative_name, "content": content})
                file_count += 1
                byte_count += actual_size

        directories.append({"root": str(root), "files": collected_files})

    return DirectoryContext(directories, file_count, byte_count, skipped_count)


def build_user_content(prompt: str, context: DirectoryContext) -> str:
    if not context.directories:
        return prompt
    return json.dumps(
        {"task": prompt, "directory_context": context.directories},
        ensure_ascii=False,
    )


def context_summary(context: DirectoryContext) -> str:
    return (
        f"Directory context: {context.file_count} file(s), "
        f"{context.byte_count} UTF-8 bytes, {context.skipped_count} skipped"
    )


def _include_directory(
    path: Path, directory_name: str, args: argparse.Namespace
) -> bool:
    if path.is_symlink() or directory_name in EXCLUDED_DIRECTORIES:
        return False
    return args.include_hidden or not directory_name.startswith(".")


def _include_file(path: Path, relative_name: str, args: argparse.Namespace) -> bool:
    if path.is_symlink() or not path.is_file():
        return False
    lowered_name = path.name.lower()
    if (
        lowered_name in SENSITIVE_NAMES
        or lowered_name.startswith(".env.")
        or path.suffix.lower() in SENSITIVE_SUFFIXES
    ):
        return False
    if not args.include_hidden and any(
        part.startswith(".") for part in Path(relative_name).parts
    ):
        return False
    if args.include and not any(
        PurePosixPath(relative_name).match(pattern) for pattern in args.include
    ):
        return False
    return True
