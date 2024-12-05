import sys
import curses

service_list = sys.argv[1:]
selection = ""


def display_output(stdscr):
    stdscr.clear()
    try:
        stdscr.addstr(0, 0, f"atstrigger: press <q> to quit...", curses.A_BOLD)
        for i, service in enumerate(service_list):
            stdscr.addstr(i + 2, 3, f"{i+1}: {service}")
        stdscr.refresh()
    except:
        pass


def main(stdscr):
    global selection
    global service_list
    curses.curs_set(0)
    stdscr.clear()

    while True:
        display_output(stdscr)

        key = stdscr.getch()

        if key == ord("q"):
            break

        elif key.isnumeric():
            k = int(key)
            if 1 <= k <= len(service_list):
                selection = service_list[k - 1]
                break


if __name__ == "__main__":
    global selection
    curses.wrapper(main)
    print(selection)
