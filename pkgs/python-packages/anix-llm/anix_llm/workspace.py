"""Create the anix-llm tmux workspace."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from pathlib import Path


def launch_workspace(
    *,
    session: str,
    cli_path: str,
    base_args: list[str],
    output_dir: Path,
    prompt: str | None,
    context_dirs: list[Path],
    includes: list[str],
) -> None:
    tmux = shutil.which("tmux")
    bash = shutil.which("bash")
    journalctl = shutil.which("journalctl")
    if tmux is None or bash is None:
        raise RuntimeError("workspace requires tmux and bash")

    if (
        subprocess.run(
            [tmux, "has-session", "-t", session],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        != 0
    ):
        cli = [cli_path, *base_args]
        status_script = f"{shlex.join([*cli, 'status'])}; "
        if journalctl:
            status_script += f"exec {shlex.join([journalctl, '-fu', 'ollama'])}"
        else:
            status_script += "exec bash -i"

        ask_script = f"{shlex.join([*cli, 'ask'])}; exec bash -i"

        write_command = [*cli, "write", "--output-dir", str(output_dir)]
        for context_dir in context_dirs:
            write_command.extend(["--context", str(context_dir)])
        for pattern in includes:
            write_command.extend(["--include", pattern])
        if prompt:
            write_command.append(prompt)
        writer_script = f"{shlex.join(write_command)}; exec bash -i"

        server_pane = _capture(
            tmux,
            [
                "new-session",
                "-d",
                "-P",
                "-F",
                "#{pane_id}",
                "-s",
                session,
                "-n",
                "local-llm",
                shlex.join([bash, "-lc", status_script]),
            ],
        )
        chat_pane = _capture(
            tmux,
            [
                "split-window",
                "-h",
                "-P",
                "-F",
                "#{pane_id}",
                "-t",
                server_pane,
                shlex.join([*cli, "chat"]),
            ],
        )
        ask_pane = _capture(
            tmux,
            [
                "split-window",
                "-v",
                "-P",
                "-F",
                "#{pane_id}",
                "-t",
                chat_pane,
                shlex.join([bash, "-lc", ask_script]),
            ],
        )
        writer_pane = _capture(
            tmux,
            [
                "split-window",
                "-v",
                "-P",
                "-F",
                "#{pane_id}",
                "-t",
                ask_pane,
                shlex.join([bash, "-lc", writer_script]),
            ],
        )
        subprocess.run(
            [tmux, "select-layout", "-t", server_pane, "main-vertical"],
            check=True,
        )
        for pane, title in (
            (server_pane, "Ollama service"),
            (chat_pane, "Private in-memory chat"),
            (ask_pane, "Normal text client"),
            (writer_pane, "Guarded file writer"),
        ):
            subprocess.run([tmux, "select-pane", "-t", pane, "-T", title], check=True)
        subprocess.run(
            [tmux, "set-option", "-t", session, "pane-border-status", "top"],
            check=True,
        )
        subprocess.run(
            [
                tmux,
                "set-option",
                "-t",
                session,
                "pane-border-format",
                " #{pane_title} ",
            ],
            check=True,
        )
        subprocess.run([tmux, "select-pane", "-t", writer_pane], check=True)

    if os.environ.get("TMUX"):
        os.execv(tmux, [tmux, "switch-client", "-t", session])
    os.execv(tmux, [tmux, "attach-session", "-t", session])


def _capture(tmux: str, arguments: list[str]) -> str:
    return subprocess.check_output([tmux, *arguments], text=True).strip()
