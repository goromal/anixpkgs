import sys # ^^^^ TODO get passed dev_dir, wsname
import curses

def main(stdscr):
    # Turn off cursor blinking
    curses.curs_set(0)
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)
    curses.init_pair(2, curses.COLOR_RED, curses.COLOR_BLACK)

    # Clear the screen
    stdscr.clear()

    # Define a list of words
    wsname = "personal"
    repos = [ # ^^^^ TODO only refresh after a cmd
        ("anixpkgs","master",True,"asdfasdfs"),
        ("manif-geom-cpp","main",False,"asfasddds"),
        ("geometry","dev/foo",False,"lasdfasdf"),
        ("pyceres_factors","master",True,"asdfasds"),
    ]
    max_reponame_len = max([len(repo[0]) for repo in repos])
    max_branch_len = max([len(repo[1]) for repo in repos])
    status_msg = "AWAITING COMMAND"
    TMP_ctr = 0

    # Initialize variables for scrolling and selecting
    start_row = 2
    current_row = start_row
    end_row = min(2 + len(repos), curses.LINES - 1)  # One less for the status bar
    selected_word = None

    while True:
        stdscr.clear()

        # Display the list of words
        stdscr.addstr(0, 0, f"Workspace \"{wsname}\"", curses.A_BOLD)

        for i in range(start_row, end_row):
            if i == current_row:
                stdscr.addstr(i, 0, repos[i - start_row][0], curses.A_REVERSE)
            else:
                stdscr.addstr(i, 0, repos[i - start_row][0])
            stdscr.addstr(i, max_reponame_len+1, f"({'CLEAN' if repos[i-start_row][2] else 'DIRTY'})", curses.color_pair(1) if repos[i-start_row][2] else curses.color_pair(2))
            stdscr.addstr(i, max_reponame_len+10, repos[i-start_row][1], curses.A_BOLD)
            stdscr.addstr(i, max_reponame_len+max_branch_len+11, repos[i-start_row][3])
        
        stdscr.addstr(end_row+1, 0, status_msg, curses.A_BOLD)
        stdscr.addstr(end_row+3, 0, "[e]  Open in editor")
        stdscr.addstr(end_row+4, 0, "[s]  Stash changes")
        stdscr.addstr(end_row+5, 0, "[p]  Push current branch")
        stdscr.addstr(end_row+6, 0, "[b]  Create new branch")
        stdscr.addstr(end_row+7, 0, "[c]  (Stash and) CheckOut and Pull")
        stdscr.addstr(end_row+8, 0, "[h]  Display the full HEAD hash")
        stdscr.addstr(end_row+9, 0, "[q]  Quit")

        # Refresh the screen
        stdscr.refresh()

        # Get user input
        key = stdscr.getch()

        # Handle user input
        if key == curses.KEY_UP:
            current_row -= 1
            if current_row < start_row:
                current_row = end_row-1
        elif key == curses.KEY_DOWN:
            current_row += 1
            if current_row > end_row-1:
                current_row = start_row
        elif key == ord('g'):
            # Check if the current selected word is "grape"
            if repos[current_row - start_row][0] == "anixpkgs":
                # Call a callback function specific to "grape"
                grape_callback(stdscr)
        elif key == ord('q'):
            # Quit the program if 'q' is pressed
            break

        TMP_ctr += 1
        status_msg = f"ITER {TMP_ctr}"

    # Return the selected word
    return selected_word

def grape_callback(stdscr):
    # Clear the screen
    stdscr.clear()
    # Display the prompt
    stdscr.addstr(0, 0, "You pressed 'g' on the word 'grape'.", curses.A_BOLD)
    stdscr.addstr(1, 0, "Please type in a type of sandwich: ", curses.A_NORMAL)
    # Refresh the screen
    stdscr.refresh()

    # Create an input box
    curses.echo()  # Enable echo to show user input
    stdscr.move(1, len("Please type in a type of sandwich: "))
    sandwich = stdscr.getstr(1, len("Please type in a type of sandwich: ")).decode(encoding="utf-8")

    # Display the entered sandwich
    stdscr.addstr(2, 0, f"You entered: {sandwich}", curses.A_NORMAL)
    stdscr.refresh()
    # Wait for a key press to continue
    stdscr.getch()

if __name__ == "__main__":
    # Initialize curses
    curses.wrapper(main)
