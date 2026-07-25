import sys
import os
import curses


def parse_workspaces(devrcfile):
    reserved = {"dev_dir", "data_dir", "pkgs_dir", "pkgs_var"}
    ws_order = []
    workspaces = {}
    repos = {}
    scripts = {}

    with open(devrcfile, "r") as f:
        for line in f:
            if "#" in line or "=" not in line:
                continue
            left = line.split("=")[0].strip()
            right = line.split("=")[1].strip()
            if not left or left in reserved:
                continue
            elif left.startswith("["):
                repos[left.replace("[", "").replace("]", "")] = right
            elif left.startswith("<"):
                scripts[left.replace("<", "").replace(">", "")] = right
            else:
                if left not in workspaces:
                    ws_order.append(left)
                workspaces[left] = right.split() if right else []

    return ws_order, workspaces, repos, scripts


def draw_screen(stdscr, ws_order, workspaces, repos, scripts, current):
    stdscr.clear()
    height, width = stdscr.getmaxyx()

    max_ws_len = max((len(ws) for ws in ws_order), default=10)
    list_col_width = max(max_ws_len + 4, 20)
    divider_col = list_col_width
    preview_col = divider_col + 2

    try:
        stdscr.addstr(0, 0, "Workspaces", curses.A_BOLD)
    except Exception:
        pass

    if preview_col < width and ws_order:
        preview_header = f"Preview: {ws_order[current]}"
        try:
            stdscr.addstr(0, preview_col, preview_header, curses.A_BOLD | curses.color_pair(3))
        except Exception:
            pass

    for row in range(1, height - 1):
        if divider_col < width:
            try:
                stdscr.addch(row, divider_col, "|")
            except Exception:
                pass

    list_start_row = 2
    for i, ws in enumerate(ws_order):
        row = list_start_row + i
        if row >= height - 1:
            break
        try:
            if i == current:
                stdscr.addstr(row, 0, f"> {ws}", curses.A_REVERSE)
            else:
                stdscr.addstr(row, 2, ws)
        except Exception:
            pass

    if ws_order and preview_col < width:
        selected_ws = ws_order[current]
        sources = workspaces.get(selected_ws, [])

        repo_sources = [s for s in sources if s in repos]
        script_sources = [s for s in sources if s in scripts]
        other_sources = [s for s in sources if s not in repos and s not in scripts]
        all_repos = repo_sources + other_sources

        preview_row = 2

        if all_repos:
            try:
                stdscr.addstr(preview_row, preview_col, "Repos:", curses.color_pair(1) | curses.A_BOLD)
            except Exception:
                pass
            preview_row += 1
            for s in all_repos:
                if preview_row >= height - 1:
                    break
                try:
                    stdscr.addstr(preview_row, preview_col + 2, s, curses.color_pair(3))
                except Exception:
                    pass
                preview_row += 1
        else:
            try:
                stdscr.addstr(preview_row, preview_col, "(no repos)", curses.color_pair(4))
            except Exception:
                pass
            preview_row += 1

        if script_sources:
            preview_row += 1
            if preview_row < height - 1:
                try:
                    stdscr.addstr(preview_row, preview_col, "Scripts:", curses.color_pair(1) | curses.A_BOLD)
                except Exception:
                    pass
                preview_row += 1
                for s in script_sources:
                    if preview_row >= height - 1:
                        break
                    try:
                        stdscr.addstr(preview_row, preview_col + 2, s, curses.color_pair(2))
                    except Exception:
                        pass
                    preview_row += 1

    footer = "UP/DOWN: navigate  ENTER: select  q: quit"
    try:
        stdscr.addstr(height - 1, 0, footer, curses.A_BOLD)
    except Exception:
        pass

    stdscr.refresh()


def main(stdscr):
    devrcfile = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.devrc")

    if not os.path.exists(devrcfile):
        return None

    ws_order, workspaces, repos, scripts = parse_workspaces(devrcfile)

    if not ws_order:
        return None

    curses.curs_set(0)
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_YELLOW, curses.COLOR_BLACK)
    curses.init_pair(3, curses.COLOR_CYAN, curses.COLOR_BLACK)
    curses.init_pair(4, curses.COLOR_RED, curses.COLOR_BLACK)

    current = 0

    while True:
        draw_screen(stdscr, ws_order, workspaces, repos, scripts, current)

        key = stdscr.getch()

        if key == curses.KEY_UP:
            current = (current - 1) % len(ws_order)
        elif key == curses.KEY_DOWN:
            current = (current + 1) % len(ws_order)
        elif key in (curses.KEY_ENTER, ord("\n"), ord("\r")):
            return ws_order[current]
        elif key == ord("q") or key == 27:
            return None

    return None


if __name__ == "__main__":
    # When stdout is captured via $(...), it's not a TTY and curses fails.
    # Save the real stdout fd, redirect stdin/stdout to /dev/tty for curses,
    # then restore and write the result to the captured stdout.
    orig_stdout_fd = os.dup(sys.stdout.fileno())
    tty_fd = os.open("/dev/tty", os.O_RDWR)
    os.dup2(tty_fd, sys.stdin.fileno())
    os.dup2(tty_fd, sys.stdout.fileno())
    os.close(tty_fd)

    result = curses.wrapper(main)

    os.dup2(orig_stdout_fd, sys.stdout.fileno())
    os.close(orig_stdout_fd)

    if result:
        print(result)
