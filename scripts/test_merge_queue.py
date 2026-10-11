import unittest

from scripts.merge_queue import (
    Eject,
    Merge,
    PrState,
    QueueState,
    UpdateBranch,
    Wait,
    _json_stream,
    ci_result,
    decide,
    is_follow_on,
    is_fresh,
    order_queue,
    release_type,
    run,
)


def commit(author, message):
    return {"commit": {"author": {"name": author}, "message": message}}


BUMP = commit("goromal (bot)", "Bump patch ANIX_VERSION -> 9.5.1")
DOCS = commit("goromal (bot)", "Generate updated docs")
HUMAN = commit("Andrew Torgesen", "cozy: one-click add-to-queue button (#669)")


def ci_run(status, conclusion=None, created_at="2026-10-10T00:00:00Z", url="https://ci/1"):
    return {
        "status": status,
        "conclusion": conclusion,
        "created_at": created_at,
        "html_url": url,
    }


def pr(**overrides):
    fields = dict(
        number=7,
        title="Add thing",
        head_sha="abc123",
        head_ref="dev/thing",
        draft=False,
        from_fork=False,
        mergeable=True,
        labels=["merge-queue"],
        behind_commits=[],
        ci="green",
        ci_url="https://ci/1",
    )
    fields.update(overrides)
    return PrState(**fields)


def state(head=None, busy=False, paused=False):
    return QueueState(paused=paused, master_writer_busy=busy, head=head)


class IsFollowOnTest(unittest.TestCase):
    def test_version_bumps_are_follow_ons(self):
        for kind in ("major", "minor", "patch"):
            self.assertTrue(
                is_follow_on(commit("goromal (bot)", f"Bump {kind} ANIX_VERSION -> 10.0.0"))
            )

    def test_docs_regeneration_is_follow_on(self):
        self.assertTrue(is_follow_on(DOCS))

    def test_human_commit_is_not_follow_on(self):
        self.assertFalse(is_follow_on(HUMAN))

    def test_bot_subject_from_human_is_not_follow_on(self):
        self.assertFalse(is_follow_on(commit("Andrew Torgesen", "Generate updated docs")))

    def test_other_bot_commits_are_not_follow_ons(self):
        self.assertFalse(is_follow_on(commit("goromal (bot)", "Lint format")))
        self.assertFalse(is_follow_on(commit("goromal (bot)", "Update flake lock")))

    def test_only_subject_line_is_matched(self):
        self.assertTrue(is_follow_on(commit("goromal (bot)", "Generate updated docs\n\nbody")))


class IsFreshTest(unittest.TestCase):
    def test_not_behind_is_fresh(self):
        self.assertTrue(is_fresh([], True))

    def test_behind_only_by_follow_ons_is_fresh(self):
        self.assertTrue(is_fresh([BUMP, DOCS], True))

    def test_behind_by_human_commit_is_stale(self):
        self.assertFalse(is_fresh([BUMP, HUMAN, DOCS], True))

    def test_conflicting_is_stale(self):
        self.assertFalse(is_fresh([], False))


class CiResultTest(unittest.TestCase):
    def test_no_runs_is_pending(self):
        self.assertEqual(ci_result([]), ("pending", None))

    def test_in_progress_is_pending(self):
        self.assertEqual(ci_result([ci_run("in_progress")]), ("pending", "https://ci/1"))

    def test_success_is_green(self):
        self.assertEqual(ci_result([ci_run("completed", "success")]), ("green", "https://ci/1"))

    def test_failure_and_cancelled_are_red(self):
        for conclusion in ("failure", "cancelled", "timed_out"):
            self.assertEqual(ci_result([ci_run("completed", conclusion)])[0], "red")

    def test_latest_run_wins(self):
        runs = [
            ci_run("completed", "failure", "2026-10-10T01:00:00Z", "https://ci/old"),
            ci_run("completed", "success", "2026-10-10T02:00:00Z", "https://ci/new"),
        ]
        self.assertEqual(ci_result(runs), ("green", "https://ci/new"))


class ReleaseTypeTest(unittest.TestCase):
    def test_precedence(self):
        self.assertEqual(release_type(["PatchRelease", "MajorRelease"]), "major")
        self.assertEqual(release_type(["PatchRelease", "MinorRelease"]), "minor")
        self.assertEqual(release_type(["PatchRelease"]), "patch")
        self.assertEqual(release_type(["merge-queue"]), "none")


class OrderQueueTest(unittest.TestCase):
    def test_fifo_by_label_time_then_number(self):
        entries = [
            {"number": 9, "labeled_at": "2026-10-10T03:00:00Z"},
            {"number": 8, "labeled_at": "2026-10-10T01:00:00Z"},
            {"number": 5, "labeled_at": "2026-10-10T03:00:00Z"},
        ]
        self.assertEqual([e["number"] for e in order_queue(entries)], [8, 5, 9])


class DecideTest(unittest.TestCase):
    def test_waits_while_paused(self):
        self.assertIsInstance(decide(state(pr(), paused=True)), Wait)

    def test_waits_while_master_writer_busy(self):
        self.assertIsInstance(decide(state(pr(), busy=True)), Wait)

    def test_waits_when_queue_empty(self):
        self.assertIsInstance(decide(state(None)), Wait)

    def test_ejects_draft(self):
        self.assertEqual(decide(state(pr(draft=True))), Eject(7, "PR is a draft"))

    def test_ejects_fork(self):
        self.assertEqual(
            decide(state(pr(from_fork=True))), Eject(7, "PRs from forks are not supported")
        )

    def test_waits_for_mergeability(self):
        self.assertIsInstance(decide(state(pr(mergeable=None))), Wait)

    def test_updates_stale_branch_even_if_green(self):
        self.assertEqual(
            decide(state(pr(behind_commits=[HUMAN]))), UpdateBranch(7, "dev/thing")
        )

    def test_updates_conflicting_branch(self):
        self.assertEqual(decide(state(pr(mergeable=False))), UpdateBranch(7, "dev/thing"))

    def test_waits_for_pending_ci(self):
        self.assertIsInstance(decide(state(pr(ci="pending"))), Wait)

    def test_ejects_red_ci_with_link(self):
        self.assertEqual(
            decide(state(pr(ci="red"))), Eject(7, "CI failed: https://ci/1")
        )

    def test_merges_green_fresh_pr_behind_only_by_follow_ons(self):
        head = pr(behind_commits=[BUMP, DOCS], labels=["merge-queue", "PatchRelease"])
        self.assertEqual(decide(state(head)), Merge(7, "abc123", "patch", "Add thing"))


class JsonStreamTest(unittest.TestCase):
    def test_parses_compact_and_pretty_values(self):
        text = '{"a": 1}\n{\n  "b": [2, 3]\n}\n\n'
        self.assertEqual(_json_stream(text), [{"a": 1}, {"b": [2, 3]}])

    def test_empty_output(self):
        self.assertEqual(_json_stream(""), [])


class FakeClient:
    def __init__(self, states, update_result=(True, None), merge_result=(True, None)):
        self.states = list(states)
        self.update_result = update_result
        self.merge_result = merge_result
        self.calls = []

    def fetch_state(self):
        return self.states.pop(0)

    def eject(self, action):
        self.calls.append(("eject", action.number, action.reason))

    def update_branch(self, action):
        self.calls.append(("update", action.number))
        return self.update_result

    def comment(self, number, body):
        self.calls.append(("comment", number))

    def merge(self, action):
        self.calls.append(("merge", action.number))
        return self.merge_result


class RunTest(unittest.TestCase):
    def test_ejects_red_head_then_merges_next(self):
        client = FakeClient([state(pr(number=1, ci="red")), state(pr(number=2))])
        result = run(client)
        self.assertEqual(result, Merge(2, "abc123", "none", "Add thing"))
        self.assertEqual(
            client.calls, [("eject", 1, "CI failed: https://ci/1"), ("merge", 2)]
        )

    def test_update_conflict_ejects_and_continues(self):
        client = FakeClient(
            [state(pr(number=1, mergeable=False)), state(None)],
            update_result=(False, "conflicts with master"),
        )
        self.assertIsInstance(run(client), Wait)
        self.assertEqual(
            client.calls, [("update", 1), ("eject", 1, "conflicts with master")]
        )

    def test_successful_update_comments_and_stops(self):
        client = FakeClient([state(pr(number=1, behind_commits=[HUMAN]))])
        self.assertEqual(run(client), UpdateBranch(1, "dev/thing"))
        self.assertEqual(client.calls, [("update", 1), ("comment", 1)])

    def test_retryable_merge_failure_waits(self):
        client = FakeClient([state(pr(number=1))], merge_result=(False, None))
        self.assertIsInstance(run(client), Wait)
        self.assertEqual(client.calls, [("merge", 1)])

    def test_permanent_merge_failure_ejects_and_continues(self):
        client = FakeClient(
            [state(pr(number=1)), state(None)],
            merge_result=(False, "merge rejected: HTTP 403"),
        )
        self.assertIsInstance(run(client), Wait)
        self.assertEqual(
            client.calls, [("merge", 1), ("eject", 1, "merge rejected: HTTP 403")]
        )

    def test_wait_stops_without_actions(self):
        client = FakeClient([state(pr(), busy=True)])
        self.assertIsInstance(run(client), Wait)
        self.assertEqual(client.calls, [])

    def test_bounded_steps(self):
        client = FakeClient([state(pr(number=n, draft=True)) for n in range(3)])
        self.assertIsInstance(run(client, max_steps=3), Wait)
        self.assertEqual(len(client.calls), 3)


if __name__ == "__main__":
    unittest.main()
