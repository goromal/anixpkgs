#!/usr/bin/env python3
"""Home VPN toggle — thin GTK front-end over the `homevpn` CLI."""
import subprocess

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")
from gi.repository import Adw, GLib, Gtk  # noqa: E402

HOMEVPN = "@homevpn@"  # replaced at build with the absolute homevpn path
POLL_MS = 1500

# state key -> (subtitle, switch_on, sensitive, dot_emoji)
STATE_UI = {
    "unconfigured": ("No VPN configured — create ~/secrets/vpn/auth.txt", False, False, "⚪"),
    "off": ("Off", False, True, "⚪"),
    "connecting": ("Connecting…", True, True, "\U0001f7e0"),
    "auth-failed": ("Authentication failed — check auth.txt", False, True, "\U0001f534"),
}


def run_homevpn(*args):
    try:
        return subprocess.run(
            [HOMEVPN, *args], capture_output=True, text=True, timeout=10
        ).stdout.strip()
    except Exception:
        return ""


class HomeVpnWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Home VPN")
        self.set_default_size(380, 150)
        self._suppress = False

        self.dot = Gtk.Label(label="⚪")
        self.switch = Gtk.Switch(valign=Gtk.Align.CENTER)
        self.switch.connect("notify::active", self._on_switch)

        self.row = Adw.ActionRow(title="Home VPN", subtitle="…")
        self.row.add_prefix(self.dot)
        self.row.add_suffix(self.switch)
        self.row.set_activatable_widget(self.switch)

        group = Adw.PreferencesGroup()
        group.add(self.row)
        clamp = Adw.Clamp(
            child=group, margin_top=18, margin_bottom=18, margin_start=12, margin_end=12
        )

        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar())
        view.set_content(clamp)
        self.set_content(view)

        self._refresh()
        GLib.timeout_add(POLL_MS, self._tick)

    def _refresh(self):
        parts = (run_homevpn("state") or "off").split()
        key = parts[0]
        if key == "connected":
            ip = parts[1] if len(parts) > 1 else "?"
            subtitle, on, sensitive, dot = (
                f"Connected · tun0 · {ip}",
                True,
                True,
                "\U0001f7e2",
            )
        else:
            subtitle, on, sensitive, dot = STATE_UI.get(key, ("Off", False, True, "⚪"))
        self._suppress = True
        self.switch.set_active(on)
        self._suppress = False
        self.switch.set_sensitive(sensitive)
        self.row.set_subtitle(subtitle)
        self.dot.set_label(dot)

    def _tick(self):
        self._refresh()
        return GLib.SOURCE_CONTINUE

    def _on_switch(self, switch, _pspec):
        if self._suppress:
            return
        run_homevpn("on" if switch.get_active() else "off")
        GLib.timeout_add(500, self._refresh_once)

    def _refresh_once(self):
        self._refresh()
        return GLib.SOURCE_REMOVE


class HomeVpnApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="dev.anix.HomeVpn")

    def do_activate(self):
        win = self.get_active_window() or HomeVpnWindow(self)
        win.present()


if __name__ == "__main__":
    HomeVpnApp().run()
