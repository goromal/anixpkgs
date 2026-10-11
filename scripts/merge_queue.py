"""Serialized FIFO merge queue for anixpkgs, driven by .github/workflows/merge-queue.yml.

Each invocation derives the queue state from GitHub, takes at most one advancing
action (update a branch or merge), and exits; later workflow triggers re-run it.
"""

import re
from dataclasses import dataclass
from typing import Optional

QUEUE_LABEL = "merge-queue"
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
