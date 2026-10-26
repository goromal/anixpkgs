"""Serialized FIFO merge queue for anixpkgs, driven by .github/workflows/merge-queue.yml.

Each invocation derives the queue state from GitHub, takes at most one advancing
action (update a branch or merge), and exits; later workflow triggers re-run it.
"""

import json
import os
import re
import subprocess
import time
from dataclasses import dataclass
from typing import Optional

QUEUE_LABEL = "merge-queue"
PAUSE_LABEL = "merge-queue-paused"
BOT_AUTHOR = "goromal (bot)"
FOLLOW_ON_SUBJECTS = [
    re.compile(r"^Bump (major|minor|patch) ANIX_VERSION -> \S+$"),
    re.compile(r"^Generate updated docs$"),
]
RELEASE_LABELS = [
    ("MajorRelease", "major"),
    ("MinorRelease", "minor"),
    ("PatchRelease", "patch"),
]

CI_WORKFLOW = "test.yml"
MASTER_WRITER_WORKFLOWS = ["deploy.yml", "manual-release.yml"]
MERGEABLE_POLLS = 6
MERGEABLE_POLL_SECONDS = 10


@dataclass(frozen=True)
class PrState:
    number: int
    title: str
    head_sha: str
    head_ref: str
    draft: bool
    from_fork: bool
    mergeable: Optional[bool]
    labels: list
    behind_commits: list
    ci: str
    ci_url: Optional[str]


@dataclass(frozen=True)
class QueueState:
    paused: bool
    master_writer_busy: bool
    head: Optional[PrState]


@dataclass(frozen=True)
class Wait:
    reason: str


@dataclass(frozen=True)
class Eject:
    number: int
    reason: str


@dataclass(frozen=True)
class UpdateBranch:
    number: int
    head_ref: str


@dataclass(frozen=True)
class Merge:
    number: int
    head_sha: str
    release: str
    title: str


def is_follow_on(commit):
    """True for the bot commits deploy.yml pushes to master after a merge."""
    subject = commit["commit"]["message"].splitlines()[0]
    return commit["commit"]["author"]["name"] == BOT_AUTHOR and any(
        pattern.match(subject) for pattern in FOLLOW_ON_SUBJECTS
    )


def is_fresh(behind_commits, mergeable):
    return mergeable is not False and all(is_follow_on(c) for c in behind_commits)


def ci_result(runs):
    if not runs:
        return "pending", None
    latest = max(runs, key=lambda r: r["created_at"])
    if latest["status"] != "completed":
        return "pending", latest["html_url"]
    if latest["conclusion"] == "success":
        return "green", latest["html_url"]
    return "red", latest["html_url"]


def release_type(labels):
    for label, release in RELEASE_LABELS:
        if label in labels:
            return release
    return "none"


def order_queue(entries):
    return sorted(entries, key=lambda e: (e["labeled_at"], e["number"]))


def decide(state):
    if state.paused:
        return Wait(f"queue is paused; close the open `{PAUSE_LABEL}` issue to resume")
    if state.master_writer_busy:
        return Wait("a workflow that writes to master is running")
    pr = state.head
    if pr is None:
        return Wait("queue is empty")
    if pr.draft:
        return Eject(pr.number, "PR is a draft")
    if pr.from_fork:
        return Eject(pr.number, "PRs from forks are not supported")
    if pr.mergeable is None:
        return Wait(f"mergeability of #{pr.number} is not computed yet")
    if not is_fresh(pr.behind_commits, pr.mergeable):
        return UpdateBranch(pr.number, pr.head_ref)
    if pr.ci == "pending":
        return Wait(f"CI for #{pr.number} is pending")
    if pr.ci == "red":
        return Eject(pr.number, f"CI failed: {pr.ci_url}")
    return Merge(pr.number, pr.head_sha, release_type(pr.labels), pr.title)


def run(client, max_steps=20):
    """Advance the queue; returns the action that ended this invocation."""
    for _ in range(max_steps):
        action = decide(client.fetch_state())
        print(f"merge-queue: {action}")
        if isinstance(action, Eject):
            client.eject(action)
            continue
        if isinstance(action, UpdateBranch):
            updated, reason = client.update_branch(action)
            if not updated:
                client.eject(Eject(action.number, reason))
                continue
            client.comment(
                action.number,
                "Merge queue: merged `master` into this branch; waiting for CI.",
            )
            return action
        if isinstance(action, Merge):
            merged, reason = client.merge(action)
            if merged:
                return action
            if reason is None:
                return Wait(f"merge of #{action.number} raced a push; will retry")
            client.eject(Eject(action.number, reason))
            continue
        return action
    return Wait("step limit reached")


def _json_stream(text):
    """Parse whitespace-separated JSON values, as emitted by `gh api --jq`."""
    decoder = json.JSONDecoder()
    values, pos = [], 0
    while True:
        while pos < len(text) and text[pos].isspace():
            pos += 1
        if pos == len(text):
            return values
        value, pos = decoder.raw_decode(text, pos)
        values.append(value)


def _sh(*args, check=True):
    return subprocess.run(args, check=check, capture_output=True, text=True)


class GitHub:
    def __init__(self, repo):
        self.repo = repo

    def _get(self, path):
        return json.loads(_sh("gh", "api", path).stdout)

    def _jsonl(self, path, jq, paginate=False):
        args = ["gh", "api", path, "--jq", jq]
        if paginate:
            args.insert(2, "--paginate")
        return _json_stream(_sh(*args).stdout)

    def master_writer_busy(self):
        for workflow in MASTER_WRITER_WORKFLOWS:
            runs = self._jsonl(
                f"repos/{self.repo}/actions/workflows/{workflow}/runs?per_page=20",
                ".workflow_runs[] | {status}",
            )
            if any(r["status"] != "completed" for r in runs):
                return True
        return False

    def queued_numbers(self):
        entries = self._jsonl(
            f"repos/{self.repo}/issues?labels={QUEUE_LABEL}&state=open&per_page=100",
            ".[] | select(.pull_request) | {number}",
            paginate=True,
        )
        return [e["number"] for e in entries]

    def labeled_at(self, number):
        events = self._jsonl(
            f"repos/{self.repo}/issues/{number}/events?per_page=100",
            f'.[] | select(.event == "labeled" and .label.name == "{QUEUE_LABEL}")'
            " | {created_at}",
            paginate=True,
        )
        return max((e["created_at"] for e in events), default="")

    def fetch_pr(self, number):
        pr = self._get(f"repos/{self.repo}/pulls/{number}")
        for _ in range(MERGEABLE_POLLS):
            if pr["mergeable"] is not None:
                break
            time.sleep(MERGEABLE_POLL_SECONDS)
            pr = self._get(f"repos/{self.repo}/pulls/{number}")
        head_sha = pr["head"]["sha"]
        behind = self._jsonl(
            f"repos/{self.repo}/compare/{head_sha}...master", ".commits[]"
        )
        runs = self._jsonl(
            f"repos/{self.repo}/actions/workflows/{CI_WORKFLOW}/runs"
            f"?event=pull_request&head_sha={head_sha}",
            ".workflow_runs[] | {status, conclusion, created_at, html_url}",
        )
        ci, ci_url = ci_result(runs)
        head_repo = pr["head"]["repo"]
        return PrState(
            number=number,
            title=pr["title"],
            head_sha=head_sha,
            head_ref=pr["head"]["ref"],
            draft=pr["draft"],
            from_fork=head_repo is None or head_repo["full_name"] != self.repo,
            mergeable=pr["mergeable"],
            labels=[label["name"] for label in pr["labels"]],
            behind_commits=behind,
            ci=ci,
            ci_url=ci_url,
        )

    def paused(self):
        return bool(
            self._jsonl(
                f"repos/{self.repo}/issues?labels={PAUSE_LABEL}&state=open&per_page=1",
                ".[] | {number}",
            )
        )

    def fetch_state(self):
        if self.paused():
            return QueueState(paused=True, master_writer_busy=False, head=None)
        if self.master_writer_busy():
            return QueueState(paused=False, master_writer_busy=True, head=None)
        queue = order_queue(
            [{"number": n, "labeled_at": self.labeled_at(n)} for n in self.queued_numbers()]
        )
        head = self.fetch_pr(queue[0]["number"]) if queue else None
        return QueueState(paused=False, master_writer_busy=False, head=head)

    def comment(self, number, body):
        _sh("gh", "pr", "comment", str(number), "--repo", self.repo, "--body", body)

    def eject(self, action):
        _sh(
            "gh", "pr", "edit", str(action.number), "--repo", self.repo,
            "--remove-label", QUEUE_LABEL,
        )
        self.comment(action.number, f"Removed from merge queue: {action.reason}")

    def update_branch(self, action):
        """Merge master into the PR branch and push with the checkout's deploy key."""
        ref = action.head_ref
        _sh(
            "git", "fetch", "origin",
            "+refs/heads/master:refs/remotes/origin/master",
            f"+refs/heads/{ref}:refs/remotes/origin/{ref}",
        )
        _sh("git", "checkout", "-B", ref, f"origin/{ref}")
        try:
            before = _sh("git", "rev-parse", "HEAD").stdout.strip()
            if _sh("git", "merge", "--no-edit", "origin/master", check=False).returncode:
                _sh("git", "merge", "--abort", check=False)
                return False, "conflicts with `master`; resolve and re-add the label"
            if _sh("git", "rev-parse", "HEAD").stdout.strip() == before:
                return False, "GitHub reports it unmergeable but it already contains `master`"
            _sh("git", "push", "origin", f"HEAD:{ref}")
            return True, None
        finally:
            _sh("git", "checkout", "master")

    def merge(self, action):
        """Returns (merged, eject_reason); (False, None) means retry later."""
        try:
            _sh(
                "gh", "api", "-X", "PUT",
                f"repos/{self.repo}/pulls/{action.number}/merge",
                "-f", "merge_method=squash",
                "-f", f"sha={action.head_sha}",
                "-f", f"commit_title={action.title} (#{action.number})",
                # An explicit empty body: without one, GitHub appends a
                # Co-authored-by trailer for every other commit author on the
                # branch, so agent and bot authorship would land on master.
                "-f", "commit_message=",
            )
        except subprocess.CalledProcessError as e:
            print(f"merge-queue: merge of #{action.number} failed: {e.stderr}")
            if "(HTTP 409)" in e.stderr:
                return False, None
            return False, f"GitHub rejected the merge: {e.stderr.strip()}"
        self.comment(action.number, "Merged by the merge queue.")
        return True, None


def main():
    result = run(GitHub(os.environ["GITHUB_REPOSITORY"]))
    if isinstance(result, Merge):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write(f"merged_pr={result.number}\n")
            output.write(f"release={result.release}\n")


if __name__ == "__main__":
    main()
