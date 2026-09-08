import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from devshellctl import WorkspaceError, WorkspaceManager, parse_devrc


class WorkspaceManagerTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.dev = self.root / "dev"
        self.devrc = self.root / "devrc"
        self.history = self.root / "devhist"
        self.devrc.write_text(
            f"dev_dir = {self.dev}\n"
            f"data_dir = {self.root / 'data'}\n"
            "[repo] = git@example/repo\n"
            "<helper> = scripts/helper\n"
            "alpha = repo helper\n",
            encoding="utf-8",
        )
        self.repo = self.dev / "alpha" / "sources" / "repo"
        self.repo.mkdir(parents=True)
        subprocess.run(
            ["git", "init", "-b", "master", self.repo], check=True, capture_output=True
        )
        subprocess.run(
            ["git", "-C", self.repo, "config", "user.email", "test@example.com"],
            check=True,
        )
        subprocess.run(
            ["git", "-C", self.repo, "config", "user.name", "Test"], check=True
        )
        (self.repo / "README").write_text("test\n", encoding="utf-8")
        subprocess.run(["git", "-C", self.repo, "add", "README"], check=True)
        subprocess.run(
            ["git", "-C", self.repo, "commit", "-m", "initial"],
            check=True,
            capture_output=True,
        )
        self.manager = WorkspaceManager(self.devrc, self.history)

    def tearDown(self):
        self.temporary.cleanup()

    def test_parse_and_list(self):
        config = parse_devrc(self.devrc)
        self.assertEqual(config["workspaces"], {"alpha": ["repo", "helper"]})
        self.assertEqual(self.manager.list()[0]["name"], "alpha")

    def test_status_reports_repository(self):
        status = self.manager.status("alpha")
        repo = status["repositories"][0]
        self.assertEqual(repo["branch"], "master")
        self.assertTrue(repo["clean"])
        self.assertIsNone(repo["upstream"])
        self.assertTrue(repo["local"])

    def test_save_and_create_branch(self):
        self.manager.save_branch("alpha", "repo")
        history = json.loads(self.history.read_text(encoding="utf-8"))
        self.assertEqual(history["alpha"]["repo"]["branch"], "master")
        self.manager.create_branch("alpha", "repo", "dev/test")
        self.assertEqual(
            self.manager.status("alpha")["repositories"][0]["branch"], "dev/test"
        )

    def test_checkout_rejects_dirty_repository(self):
        (self.repo / "README").write_text("dirty\n", encoding="utf-8")
        with self.assertRaisesRegex(WorkspaceError, "uncommitted"):
            self.manager.checkout("alpha", "repo", "master")

    def test_rejects_unsafe_names(self):
        with self.assertRaisesRegex(WorkspaceError, "Invalid workspace"):
            self.manager.status("../alpha")
        with self.assertRaisesRegex(WorkspaceError, "Invalid repository"):
            self.manager.save_branch("alpha", "../repo")


if __name__ == "__main__":
    unittest.main()
