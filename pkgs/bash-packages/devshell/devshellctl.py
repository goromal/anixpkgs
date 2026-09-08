import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

SAFE_NAME = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_-]*$")
RESERVED_KEYS = {"dev_dir", "data_dir", "pkgs_dir", "pkgs_var"}


class WorkspaceError(Exception):
    pass


def parse_devrc(path):
    config = {
        "dev_dir": os.path.expanduser("~/dev"),
        "data_dir": os.path.expanduser("~/data"),
        "workspaces": {},
        "repositories": {},
        "scripts": {},
    }
    with open(os.path.expanduser(path), encoding="utf-8") as devrc:
        for raw_line in devrc:
            if "#" in raw_line or "=" not in raw_line:
                continue
            left, right = (part.strip() for part in raw_line.split("=", 1))
            if left == "dev_dir":
                config["dev_dir"] = os.path.expanduser(right)
            elif left == "data_dir":
                config["data_dir"] = os.path.expanduser(right)
            elif left.startswith("[") and left.endswith("]"):
                config["repositories"][left[1:-1]] = right
            elif left.startswith("<") and left.endswith(">"):
                config["scripts"][left[1:-1]] = right
            elif left not in RESERVED_KEYS and SAFE_NAME.fullmatch(left):
                config["workspaces"][left] = right.split()
    return config


class WorkspaceManager:
    def __init__(
        self,
        devrc="~/.devrc",
        history="~/.devhist",
        devshell_command="devshell",
        parse_script="parseWorkspace.py",
    ):
        self.devrc = os.path.expanduser(devrc)
        self.history = os.path.expanduser(history)
        self.devshell_command = devshell_command
        self.parse_script = parse_script

    def list(self):
        config = parse_devrc(self.devrc)
        return [
            {
                "name": name,
                "sources": sources,
                "root": str(Path(config["dev_dir"]) / name),
                "exists": (Path(config["dev_dir"]) / name).is_dir(),
            }
            for name, sources in config["workspaces"].items()
        ]

    def status(self, workspace):
        config, root = self._workspace(configured_name=workspace)
        history = self._read_history()
        saved = history.get(workspace, {})
        sources_dir = root / "sources"
        repository_names = [
            name
            for name in config["workspaces"][workspace]
            if name in config["repositories"]
        ]
        if sources_dir.is_dir():
            for child in sources_dir.iterdir():
                if (
                    child.is_dir()
                    and (child / ".git").exists()
                    and child.name not in repository_names
                ):
                    repository_names.append(child.name)

        repositories = []
        for name in repository_names:
            path = sources_dir / name
            if (path / ".git").exists():
                repositories.append(
                    self._repository_status(workspace, name, path, saved)
                )
            else:
                repositories.append(
                    {
                        "name": name,
                        "path": str(path),
                        "present": False,
                        "configured": True,
                    }
                )

        bin_dir = root / ".bin"
        scripts = []
        if bin_dir.is_dir():
            scripts = sorted(
                item.name
                for item in bin_dir.iterdir()
                if item.is_file() and os.access(item, os.X_OK)
            )
        return {
            "name": workspace,
            "root": str(root),
            "sources": config["workspaces"][workspace],
            "repositories": sorted(repositories, key=lambda repo: repo["name"]),
            "scripts": scripts,
        }

    def save_branch(self, workspace, repository):
        repo = self._repository(workspace, repository)
        branch = self._git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        history = self._read_history()
        history.setdefault(workspace, {}).setdefault(repository, {})["branch"] = branch
        self._write_history(history)
        return {"message": f"Saved {repository}:{branch}", "branch": branch}

    def create_branch(self, workspace, repository, branch):
        repo = self._repository(workspace, repository)
        self._validate_branch(repo, branch)
        self._git(repo, "switch", "-c", branch)
        return {"message": f"Created {repository}:{branch}"}

    def checkout(self, workspace, repository, branch, allow_dirty=False):
        repo = self._repository(workspace, repository)
        self._validate_branch(repo, branch)
        if not allow_dirty:
            self._require_clean(repo)
        self._git(repo, "fetch", "origin", branch)
        local = (
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(repo),
                    "show-ref",
                    "--verify",
                    "--quiet",
                    f"refs/heads/{branch}",
                ],
                check=False,
            ).returncode
            == 0
        )
        if local:
            self._git(repo, "switch", branch)
        else:
            self._git(repo, "switch", "--track", "-c", branch, f"origin/{branch}")
        self._git(repo, "pull", "--ff-only", "origin", branch)
        return {"message": f"Checked out {repository}:{branch}"}

    def push(self, workspace, repository):
        repo = self._repository(workspace, repository)
        branch = self._git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        self._git(repo, "push", "origin", branch)
        return {"message": f"Pushed {repository}:{branch}"}

    def sync(self, workspace, repository):
        saved = (
            self._read_history().get(workspace, {}).get(repository, {}).get("branch")
        )
        if not saved:
            raise WorkspaceError(f"No saved branch for {repository}")
        return self.checkout(workspace, repository, saved)

    def rebase_push(self, workspace, repository):
        repo = self._repository(workspace, repository)
        self._require_clean(repo)
        branch = self._git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        self._git(repo, "pull", "--rebase", "origin", branch)
        self._git(repo, "push", "origin", branch)
        return {"message": f"Rebased and pushed {repository}:{branch}"}

    def create_workspace(self, workspace):
        self._validate_name(workspace, "workspace")
        self._run_parse("ADDWS", self.devrc, workspace)
        self._setup(workspace)
        return {"message": f"Created workspace {workspace}"}

    def add_source(self, workspace, name, url=""):
        self._workspace(configured_name=workspace)
        self._validate_name(name, "repository")
        self._run_parse("ADDSRC", workspace, self.devrc, name, url)
        self._setup(workspace)
        return {"message": f"Added repository {name} to {workspace}"}

    def add_script(self, workspace, name, path=""):
        self._workspace(configured_name=workspace)
        self._validate_name(name, "script")
        self._run_parse("ADDSCR", workspace, self.devrc, name, path)
        self._setup(workspace)
        return {"message": f"Added script {name} to {workspace}"}

    def _workspace(self, configured_name):
        self._validate_name(configured_name, "workspace")
        config = parse_devrc(self.devrc)
        if configured_name not in config["workspaces"]:
            raise WorkspaceError(f"Unknown workspace: {configured_name}")
        dev_dir = Path(config["dev_dir"]).expanduser().resolve()
        root = (dev_dir / configured_name).resolve()
        if root.parent != dev_dir:
            raise WorkspaceError("Workspace path escapes dev_dir")
        return config, root

    def _repository(self, workspace, repository):
        self._validate_name(repository, "repository")
        _, root = self._workspace(configured_name=workspace)
        sources = (root / "sources").resolve()
        repo = (sources / repository).resolve()
        if repo.parent != sources or not (repo / ".git").exists():
            raise WorkspaceError(f"Unknown repository: {repository}")
        return repo

    def _repository_status(self, workspace, name, path, saved):
        branch = self._git(path, "rev-parse", "--abbrev-ref", "HEAD")
        head = self._git(path, "rev-parse", "HEAD")
        dirty = bool(self._git(path, "status", "--porcelain"))
        upstream = self._git_optional(path, "rev-parse", "--abbrev-ref", "@{upstream}")
        ahead = behind = 0
        if upstream:
            counts = self._git(
                path, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"
            )
            ahead, behind = (int(value) for value in counts.split())
        remote = self._git_optional(path, "remote", "get-url", "--push", "origin")
        return {
            "name": name,
            "path": str(path),
            "present": True,
            "configured": name in parse_devrc(self.devrc)["repositories"],
            "branch": branch,
            "head": head,
            "clean": not dirty,
            "upstream": upstream,
            "ahead": ahead,
            "behind": behind,
            "local": upstream is None or ahead > 0,
            "saved_branch": saved.get(name, {}).get("branch"),
            "remote": remote,
        }

    def _read_history(self):
        try:
            with open(self.history, encoding="utf-8") as history:
                data = json.load(history)
                return data if isinstance(data, dict) else {}
        except (OSError, ValueError):
            return {}

    def _write_history(self, data):
        path = Path(self.history)
        path.parent.mkdir(parents=True, exist_ok=True)
        fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as history:
                json.dump(data, history, indent=2, sort_keys=True)
                history.write("\n")
            os.chmod(temporary, 0o600)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def _setup(self, workspace):
        self._run(
            [
                self.devshell_command,
                workspace,
                "-d",
                self.devrc,
                "-s",
                self.history,
                "--run",
                "true",
            ],
            timeout=900,
        )

    def _run_parse(self, *args):
        self._run([sys.executable, self.parse_script, *args])

    @staticmethod
    def _validate_name(value, kind):
        if not SAFE_NAME.fullmatch(value or ""):
            raise WorkspaceError(f"Invalid {kind} name")

    def _validate_branch(self, repo, branch):
        if not branch:
            raise WorkspaceError("Branch name is required")
        result = subprocess.run(
            ["git", "-C", str(repo), "check-ref-format", "--branch", branch],
            check=False,
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise WorkspaceError("Invalid branch name")

    def _require_clean(self, repo):
        if self._git(repo, "status", "--porcelain"):
            raise WorkspaceError("Repository has uncommitted changes")

    @staticmethod
    def _git(repo, *args):
        return WorkspaceManager._run(["git", "-C", str(repo), *args]).strip()

    @staticmethod
    def _git_optional(repo, *args):
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip() if result.returncode == 0 else None

    @staticmethod
    def _run(command, timeout=300):
        try:
            result = subprocess.run(
                command,
                check=True,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except subprocess.CalledProcessError as error:
            detail = error.stderr.strip() or error.stdout.strip() or "command failed"
            raise WorkspaceError(detail) from error
        except subprocess.TimeoutExpired as error:
            raise WorkspaceError("Operation timed out") from error
        return result.stdout


def build_parser():
    parser = argparse.ArgumentParser(
        description="Noninteractive devshell workspace manager"
    )
    parser.add_argument("--devrc", default=os.environ.get("DEVSHELL_DEVRC", "~/.devrc"))
    parser.add_argument(
        "--history", default=os.environ.get("DEVSHELL_HISTORY", "~/.devhist")
    )
    parser.add_argument(
        "--devshell-command", default=os.environ.get("DEVSHELL_COMMAND", "devshell")
    )
    parser.add_argument(
        "--parse-script",
        default=os.environ.get("DEVSHELL_PARSE_SCRIPT", "parseWorkspace.py"),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("list")
    status = subparsers.add_parser("status")
    status.add_argument("workspace")
    create = subparsers.add_parser("create")
    create.add_argument("workspace")
    for command in ("save-branch", "push", "sync", "rebase-push"):
        action = subparsers.add_parser(command)
        action.add_argument("workspace")
        action.add_argument("repository")
    for command in ("branch-create", "checkout"):
        action = subparsers.add_parser(command)
        action.add_argument("workspace")
        action.add_argument("repository")
        action.add_argument("branch")
    source = subparsers.add_parser("add-source")
    source.add_argument("workspace")
    source.add_argument("name")
    source.add_argument("url", nargs="?", default="")
    script = subparsers.add_parser("add-script")
    script.add_argument("workspace")
    script.add_argument("name")
    script.add_argument("path", nargs="?", default="")
    return parser


def main():
    args = build_parser().parse_args()
    manager = WorkspaceManager(
        args.devrc, args.history, args.devshell_command, args.parse_script
    )
    methods = {
        "list": lambda: manager.list(),
        "status": lambda: manager.status(args.workspace),
        "create": lambda: manager.create_workspace(args.workspace),
        "save-branch": lambda: manager.save_branch(args.workspace, args.repository),
        "branch-create": lambda: manager.create_branch(
            args.workspace, args.repository, args.branch
        ),
        "checkout": lambda: manager.checkout(
            args.workspace, args.repository, args.branch
        ),
        "push": lambda: manager.push(args.workspace, args.repository),
        "sync": lambda: manager.sync(args.workspace, args.repository),
        "rebase-push": lambda: manager.rebase_push(args.workspace, args.repository),
        "add-source": lambda: manager.add_source(args.workspace, args.name, args.url),
        "add-script": lambda: manager.add_script(args.workspace, args.name, args.path),
    }
    try:
        result = methods[args.command]()
    except (OSError, WorkspaceError) as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
