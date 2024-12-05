import sys
import curses

service_list = sys.argv[1:]
selection = ""


def display_output(stdscr):
    global service_list
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

    idx_ords = [ord(str(i + 1)) for i in range(len(service_list))]

    while True:
        display_output(stdscr)

        key = stdscr.getch()

        if key == ord("q"):
            break

        try:
            k = idx_ords.index(key)
        except ValueError:
            k = -1

        if k > -1:
            selection = service_list[k]
            break


if __name__ == "__main__":
    curses.wrapper(main)
    print(selection.strip())
