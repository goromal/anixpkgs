from email.mime.text import MIMEText

from goromail.cli import PostfixMessage, is_task_directive, split_task_directive


GEN = "11/17/2026"


def test_task_directive_detection():
    assert is_task_directive("P0: do it")
    assert is_task_directive("p3: later")
    assert not is_task_directive("P4: nope")
    assert not is_task_directive("journal: P1: nope")


def test_single_line_task_keeps_old_shape():
    assert split_task_directive("P1: Call the bank", GEN) == (
        "P1: Call the bank",
        f"Generated: {GEN}",
    )


def test_second_line_and_beyond_become_description():
    title, notes = split_task_directive(
        "P2: Fix the fence\nNorth side, two posts.\n\n- buy concrete\n- borrow auger",
        GEN,
    )
    assert title == "P2: Fix the fence"
    assert notes == (
        "North side, two posts.\n\n- buy concrete\n- borrow auger\n\n"
        f"Generated: {GEN}"
    )


def test_crlf_and_trailing_whitespace():
    title, notes = split_task_directive("P0: Pay rent  \r\nby 5pm \r\n\r\n", GEN)
    assert title == "P0: Pay rent"
    assert notes == f"by 5pm\n\nGenerated: {GEN}"


def test_bare_prefix_line_borrows_next_line_as_title():
    title, notes = split_task_directive("P1:\n\nRenew passport\nForm DS-82", GEN)
    assert title == "P1: Renew passport"
    assert notes == f"Form DS-82\n\nGenerated: {GEN}"


def test_intake_ui_mail_keeps_newlines():
    # The intake UI writes plain-text MIME into the maildir; the body's
    # newlines must survive PostfixMessage parsing for the split to work.
    mime = MIMEText("P1: action: Title\nline two\nline three", "plain", "utf-8")
    mime["From"] = "andrew@localhost"
    msg = PostfixMessage(None, "k", mime)
    title, notes = split_task_directive(msg.getText(), GEN)
    assert title == "P1: action: Title"
    assert notes == f"line two\nline three\n\nGenerated: {GEN}"
