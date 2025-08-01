import sys
import os
import subprocess
import curses
import json


class Context:
    def __init__(self):
        self.help_mode = False
        self.dev_dir = ""
        self.hist_file = ""
        self.wsname = ""
        self.repos = []
        self.scripts = []
        self.max_reponame_len = 0
        self.max_branch_len = 0
        self.max_script_len = 0
        self.status_msg = "AWAITING COMMAND"
        self.start_row = 2
        self.current_row = self.start_row
        self.end_row = self.start_row

    def load_sources(self):
        self.repos = []
        hist_data = {}
        try:
            with open(self.hist_file, "r") as hf:
                hist_data = json.loads(hf.read())
        except:
            hist_data = {}
        self.scripts = [
            f
            for f in os.listdir(os.path.join(self.dev_dir, ".bin"))
            if os.path.isfile(os.path.join(self.dev_dir, ".bin", f))
            and os.access(os.path.join(self.dev_dir, ".bin", f), os.X_OK)
        ]
        for root, dirs, _ in os.walk(os.path.join(self.dev_dir, "sources")):
            if ".git" in dirs:
                git_dir = os.path.join(root, ".git")
                if os.path.isdir(git_dir):
                    reponame = os.path.basename(root)
                    try:
                        branch = (
                            subprocess.check_output(
                                [
                                    "git",
                                    "-C",
                                    root,
                                    "rev-parse",
                                    "--abbrev-ref",
                                    "HEAD",
                                ],
                                stderr=subprocess.PIPE,
                            )
                            .decode()
                            .strip()
                        )
                    except:
                        continue  # no branch or remote yet
                    clean = not bool(
                        subprocess.check_output(
                            ["git", "-C", root, "status", "--porcelain"],
                            stderr=subprocess.PIPE,
                        )
                        .decode()
                        .strip()
                    )
                    hash = (
                        subprocess.check_output(
                            ["git", "-C", root, "rev-parse", "HEAD"],
                            stderr=subprocess.PIPE,
                        )
                        .decode()
                        .strip()
                    )
                    try:
                        local = bool(
                            subprocess.check_output(
                                ["git", "-C", root, "log", f"origin/{branch}..HEAD"],
                                stderr=subprocess.PIPE,
                            )
                            .decode()
                            .strip()
                        )
                    except:
                        local = True  # a locally checked out branch will fail the above query
                    try:
                        sync_branch = hist_data[self.wsname][reponame]["branch"]
                    except:
                        sync_branch = None
                    url = (
                        subprocess.check_output(
                            [
                                "git",
                                "-C",
                                root,
                                "remote",
                                "get-url",
                                "--push",
                                "origin",
                            ],
                            stderr=subprocess.PIPE,
                        )
                        .decode()
                        .strip()
                    )
                    self.repos.append(
                        (reponame, branch, clean, hash, local, sync_branch, url)
                    )
        self.max_script_len = (
            max([len(script) for script in self.scripts])
            if len(self.scripts) > 0
            else 5
        )
        if len(self.repos) > 0:
            self.max_reponame_len = max([len(repo[0]) for repo in self.repos])
            self.max_branch_len = max([len(repo[1]) for repo in self.repos])
            self.end_row = min(2 + len(self.repos), curses.LINES - 1)
            self.repos.sort(key=lambda x: x[0])

    def save_ws_repo_branch(self, reponame, branch):
        hist_data = {}
        try:
            with open(self.hist_file, "r") as hf:
                hist_data = json.loads(hf.read())
        except:
            hist_data = {}
        if self.wsname not in hist_data:
            hist_data[self.wsname] = {reponame: {"branch": branch}}
        elif reponame not in hist_data[self.wsname]:
            hist_data[self.wsname][reponame] = {"branch": branch}
        else:
            hist_data[self.wsname][reponame]["branch"] = branch
        with open(self.hist_file, "w") as hf:
            hf.write(json.dumps(hist_data))


ctx = Context()


def display_output(stdscr):
    global ctx
    stdscr.clear()
    try:
        stdscr.addstr(0, 0, f'Workspace "{ctx.wsname}"', curses.A_BOLD)

        if ctx.help_mode:
            stdscr.addstr(2, 42, "-" * (ctx.max_script_len + 2))
            stdscr.addstr(3, 0, "[e]  Open in editor")
            stdscr.addstr(4, 0, "[S]  Save off staged branch")
            stdscr.addstr(5, 0, "[s]  Synchronize staged branch")
            stdscr.addstr(6, 0, "[p]  Push current branch")
            stdscr.addstr(7, 0, "[R]  Rebase-pull then push current branch")
            stdscr.addstr(8, 0, "[b]  Create new branch")
            stdscr.addstr(9, 0, "[c]  (Stash and) CheckOut and Pull")
            stdscr.addstr(10, 0, "[H]  Display the full HEAD hash")
            stdscr.addstr(11, 0, "[r]  Refresh")
            stdscr.addstr(12, 0, "[n]  Nuke")
            stdscr.addstr(13, 0, "[o]  Add source")
            stdscr.addstr(14, 0, "[i]  Add script")
            stdscr.addstr(15, 0, "[q]  Quit")
            for j, script in enumerate(ctx.scripts):
                stdscr.addstr(3 + j, 42, f"| {script}")

        else:
            for i in range(ctx.start_row, ctx.end_row):
                if i == ctx.current_row:
                    stdscr.addstr(
                        i, 0, ctx.repos[i - ctx.start_row][0], curses.A_REVERSE
                    )
                else:
                    stdscr.addstr(i, 0, ctx.repos[i - ctx.start_row][0])
                stdscr.addstr(
                    i,
                    ctx.max_reponame_len + 1,
                    f"({'CLN' if ctx.repos[i-ctx.start_row][2] else 'DTY'})",
                    (
                        curses.color_pair(1)
                        if ctx.repos[i - ctx.start_row][2]
                        else curses.color_pair(2)
                    ),
                )
                stdscr.addstr(
                    i,
                    ctx.max_reponame_len + 7,
                    f"({'LCL' if ctx.repos[i-ctx.start_row][4] else 'RMT'})",
                    (
                        curses.color_pair(2)
                        if ctx.repos[i - ctx.start_row][4]
                        else curses.color_pair(1)
                    ),
                )
                stdscr.addstr(
                    i,
                    ctx.max_reponame_len + 13,
                    ctx.repos[i - ctx.start_row][1],
                    curses.A_BOLD,
                )
                stdscr.addstr(
                    i,
                    ctx.max_reponame_len + ctx.max_branch_len + 14,
                    ctx.repos[i - ctx.start_row][3][:7],
                )
                stdscr.addstr(
                    i,
                    ctx.max_reponame_len + ctx.max_branch_len + 22,
                    (
                        ctx.repos[i - ctx.start_row][5]
                        if ctx.repos[i - ctx.start_row][5] is not None
                        else "..."
                    ),
                    (
                        curses.color_pair(3)
                        if ctx.repos[i - ctx.start_row][5] is not None
                        and ctx.repos[i - ctx.start_row][5]
                        == ctx.repos[i - ctx.start_row][1]
                        else curses.color_pair(4)
                    ),
                )
                stdscr.addstr(ctx.end_row + 1, 0, ctx.status_msg, curses.A_BOLD)

        stdscr.refresh()
    except:
        pass


def main(stdscr):
    global ctx

    ctx.wsname = sys.argv[1]
    ctx.dev_dir = sys.argv[2]
    editor = sys.argv[3]
    ctx.hist_file = sys.argv[4]
    ctx.load_sources()

    curses.curs_set(0)
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_RED, curses.COLOR_BLACK)
    curses.init_pair(3, curses.COLOR_CYAN, curses.COLOR_BLACK)
    curses.init_pair(4, curses.COLOR_YELLOW, curses.COLOR_BLACK)

    stdscr.clear()

    while True:
        display_output(stdscr)

        key = stdscr.getch()

        if key == ord("h"):
            ctx.help_mode = not ctx.help_mode
            display_output(stdscr)

        elif key == ord("q"):
            break

        elif not ctx.help_mode:

            if key == curses.KEY_UP:
                ctx.current_row -= 1
                if ctx.current_row < ctx.start_row:
                    ctx.current_row = ctx.end_row - 1

            elif key == curses.KEY_DOWN:
                ctx.current_row += 1
                if ctx.current_row > ctx.end_row - 1:
                    ctx.current_row = ctx.start_row

            elif key == ord("e"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                ctx.status_msg = f"Opening {reponame} in editor..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        [editor, os.path.join(ctx.dev_dir, "sources", reponame)],
                        stderr=subprocess.PIPE,
                    )
                except:
                    ctx.status_msg = f"Opening {reponame} in editor... UNSUCCESSFUL."
                    continue
                ctx.status_msg = f"Opening {reponame} in editor... Done."

            elif key == ord("S"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                branch = ctx.repos[ctx.current_row - ctx.start_row][1]
                ctx.status_msg = f"Saving off staging branch {reponame}:{branch}..."
                display_output(stdscr)
                ctx.save_ws_repo_branch(reponame, branch)
                ctx.load_sources()
                ctx.status_msg = (
                    f"Saving off staging branch {reponame}:{branch}... Done."
                )

            elif key == ord("s"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                repopath = os.path.join(ctx.dev_dir, "sources", reponame)
                branch = ctx.repos[ctx.current_row - ctx.start_row][5]
                if branch is not None:
                    ctx.status_msg = f"Synchonizing {reponame}:{branch}..."
                    display_output(stdscr)
                    try:
                        subprocess.check_output(
                            ["git", "-C", repopath, "stash"], stderr=subprocess.PIPE
                        )
                        subprocess.check_output(
                            ["git", "-C", repopath, "fetch", "origin", branch],
                            stderr=subprocess.PIPE,
                        )
                        subprocess.check_output(
                            ["git", "-C", repopath, "checkout", branch],
                            stderr=subprocess.PIPE,
                        )
                        subprocess.check_output(
                            ["git", "-C", repopath, "pull", "origin", branch],
                            stderr=subprocess.PIPE,
                        )
                    except:
                        ctx.load_sources()
                        ctx.status_msg = (
                            f"Synchonizing {reponame}:{branch}... UNSUCCESSFUL."
                        )
                        continue
                    ctx.load_sources()
                    ctx.status_msg = f"Synchonizing {reponame}:{branch}... Done."
                else:
                    ctx.load_sources()
                    ctx.status_msg = "No staging branch! Save one with [S]."

            elif key == ord("p"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                repopath = os.path.join(ctx.dev_dir, "sources", reponame)
                branch = ctx.repos[ctx.current_row - ctx.start_row][1]
                ctx.status_msg = f"Pushing {reponame}:{branch} to origin..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["git", "-C", repopath, "push", "origin", branch],
                        stderr=subprocess.PIPE,
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = (
                        f"Pushing {reponame}:{branch} to origin... UNSUCCESSFUL."
                    )
                    continue
                ctx.load_sources()
                ctx.status_msg = f"Pushing {reponame}:{branch} to origin... Done."

            elif key == ord("R"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                repopath = os.path.join(ctx.dev_dir, "sources", reponame)
                branch = ctx.repos[ctx.current_row - ctx.start_row][1]
                ctx.status_msg = (
                    f"Rebasing and pushing {reponame}:{branch} to origin..."
                )
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["git", "-C", repopath, "pull", "--rebase", "origin", branch],
                        stderr=subprocess.PIPE,
                    )
                    subprocess.check_output(
                        ["git", "-C", repopath, "push", "origin", branch],
                        stderr=subprocess.PIPE,
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = f"Rebasing and pushing {reponame}:{branch} to origin... UNSUCCESSFUL."
                    continue
                ctx.load_sources()
                ctx.status_msg = (
                    f"Rebasing and pushing {reponame}:{branch} to origin... Done."
                )

            elif key == ord("b"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                repopath = os.path.join(ctx.dev_dir, "sources", reponame)
                new_branch = branch_prompt(stdscr)
                ctx.status_msg = f"Creating {reponame}:{new_branch}..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["git", "-C", repopath, "checkout", "-b", new_branch],
                        stderr=subprocess.PIPE,
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = (
                        f"Creating {reponame}:{new_branch}... UNSUCCESSFUL."
                    )
                    continue
                ctx.load_sources()
                ctx.status_msg = f"Creating {reponame}:{new_branch}... Done."

            elif key == ord("c"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                repopath = os.path.join(ctx.dev_dir, "sources", reponame)
                branch = branch_prompt(stdscr)
                if not branch:
                    branch = ctx.repos[ctx.current_row - ctx.start_row][1]
                ctx.status_msg = f"Checking out {reponame}:{branch}..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["git", "-C", repopath, "stash"], stderr=subprocess.PIPE
                    )
                    subprocess.check_output(
                        ["git", "-C", repopath, "fetch", "origin", branch],
                        stderr=subprocess.PIPE,
                    )
                    subprocess.check_output(
                        ["git", "-C", repopath, "checkout", branch],
                        stderr=subprocess.PIPE,
                    )
                    subprocess.check_output(
                        ["git", "-C", repopath, "pull", "origin", branch],
                        stderr=subprocess.PIPE,
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = (
                        f"Checking out {reponame}:{branch}... UNSUCCESSFUL."
                    )
                    continue
                ctx.load_sources()
                ctx.status_msg = f"Checking out {reponame}:{branch}... Done."

            elif key == ord("o"):
                source_spec = [p for p in source_prompt(stdscr).split(" ") if p.strip()]
                ctx.status_msg = f"Adding source {source_spec[0]}..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["addsrc", *source_spec], stderr=subprocess.PIPE
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = f"Adding source {source_spec[0]}... UNSUCCESSFUL."
                    continue
                ctx.load_sources()
                ctx.status_msg = f"Adding source {source_spec[0]}... Done."

            elif key == ord("i"):
                script_spec = [p for p in script_prompt(stdscr).split(" ") if p.strip()]
                ctx.status_msg = f"Adding script {script_spec[0]}..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["addscr", *script_spec], stderr=subprocess.PIPE
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = f"Adding script {script_spec[0]}... UNSUCCESSFUL."
                    continue
                ctx.load_sources()
                ctx.status_msg = f"Adding script {script_spec[0]}... Done."

            elif key == ord("n"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                url = ctx.repos[ctx.current_row - ctx.start_row][6]
                repopath = os.path.join(ctx.dev_dir, "sources", reponame)
                branch = branch_prompt(stdscr)
                if not branch:
                    branch = ctx.repos[ctx.current_row - ctx.start_row][1]
                ctx.status_msg = f"Nuking and checking out {reponame}:{branch}..."
                display_output(stdscr)
                try:
                    subprocess.check_output(
                        ["rm", "-rf", repopath],
                        stderr=subprocess.PIPE,
                    )
                    subprocess.check_output(
                        [
                            "git",
                            "clone",
                            "--recurse-submodules",
                            url,
                            repopath,
                            "--branch",
                            branch,
                        ],
                        stderr=subprocess.PIPE,
                    )
                except:
                    ctx.load_sources()
                    ctx.status_msg = (
                        f"Nuking and checking out {reponame}:{branch}... UNSUCCESSFUL."
                    )
                    continue
                ctx.load_sources()
                ctx.status_msg = f"Nuking and checking out {reponame}:{branch}... Done."

            elif key == ord("H"):
                reponame = ctx.repos[ctx.current_row - ctx.start_row][0]
                ctx.status_msg = (
                    f"{reponame} HEAD: {ctx.repos[ctx.current_row - ctx.start_row][3]}"
                )
                display_output(stdscr)

            elif key == ord("r"):
                ctx.status_msg = "Refreshing..."
                display_output(stdscr)
                ctx.load_sources()
                ctx.status_msg = "Refreshing... Done."


def make_prompt(stdscr, prompt):
    stdscr.clear()
    stdscr.addstr(0, 0, prompt, curses.A_BOLD)
    stdscr.refresh()
    curses.echo()
    stdscr.move(0, len(prompt))
    answer = stdscr.getstr(0, len(prompt)).decode(encoding="utf-8")
    stdscr.clear()
    return answer


def branch_prompt(stdscr):
    return make_prompt(stdscr, "Branch name: ")


def source_prompt(stdscr):
    return make_prompt(stdscr, "Source_name [Source_url]: ")


def script_prompt(stdscr):
    return make_prompt(stdscr, "Script_name [Script_path]: ")


if __name__ == "__main__":
    curses.wrapper(main)
