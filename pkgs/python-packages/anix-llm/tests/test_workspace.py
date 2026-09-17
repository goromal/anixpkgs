from types import SimpleNamespace

import pytest

from anix_llm import workspace


def test_workspace_starts_interactive_clients(monkeypatch, tmp_path):
    programs = {
        "bash": "/bin/bash",
        "journalctl": "/bin/journalctl",
        "tmux": "/bin/tmux",
    }
    run_calls = []
    capture_calls = []
    pane_ids = iter(["%0", "%1", "%2", "%3"])

    monkeypatch.setattr(workspace.shutil, "which", programs.get)

    def fake_run(arguments, **kwargs):
        run_calls.append(arguments)
        return SimpleNamespace(returncode=1 if arguments[1] == "has-session" else 0)

    monkeypatch.setattr(workspace.subprocess, "run", fake_run)

    def fake_check_output(arguments, **kwargs):
        capture_calls.append(arguments)
        return next(pane_ids)

    monkeypatch.setattr(workspace.subprocess, "check_output", fake_check_output)
    monkeypatch.delenv("TMUX", raising=False)

    def fake_execv(*args):
        raise RuntimeError("attached")

    monkeypatch.setattr(workspace.os, "execv", fake_execv)

    with pytest.raises(RuntimeError, match="attached"):
        workspace.launch_workspace(
            session="test-llm",
            cli_path="/bin/anix-llm",
            base_args=["--model", "qwen:test"],
            output_dir=tmp_path,
            prompt=None,
            context_dirs=[tmp_path],
            includes=["*.py"],
        )

    assert run_calls[0] == ["/bin/tmux", "has-session", "-t", "test-llm"]
    assert "/bin/anix-llm --model qwen:test ask" in capture_calls[2][-1]
    assert "/bin/anix-llm --model qwen:test write" in capture_calls[3][-1]
    assert f"--context {tmp_path}" in capture_calls[3][-1]
