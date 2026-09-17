import unittest

from scripts.check_deps import side_branch_dependencies


def lock_with_ref(ref):
    return {"nodes": {"dependency": {"original": {"ref": ref}}}}


class CheckDependenciesTest(unittest.TestCase):
    def test_short_side_branch_is_detected(self):
        self.assertEqual(
            list(side_branch_dependencies(lock_with_ref("improve/tactical"))),
            [("dependency", "improve/tactical")],
        )

    def test_fully_qualified_side_branch_is_detected(self):
        self.assertEqual(
            list(
                side_branch_dependencies(
                    lock_with_ref("refs/heads/improve/tactical")
                )
            ),
            [("dependency", "improve/tactical")],
        )

    def test_fully_qualified_tag_is_ignored(self):
        self.assertEqual(
            list(side_branch_dependencies(lock_with_ref("refs/tags/v1.0.0"))),
            [],
        )

    def test_fully_qualified_whitelisted_branch_is_ignored(self):
        self.assertEqual(
            list(side_branch_dependencies(lock_with_ref("refs/heads/master"))),
            [],
        )


if __name__ == "__main__":
    unittest.main()
