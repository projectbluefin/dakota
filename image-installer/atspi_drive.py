#!/usr/bin/env python3
"""Read a GTK 4 application's accessibility tree from inside the guest session.

The raw-image E2E uses this to see the real OS-Installer and
gnome-initial-setup windows: which page is showing, which widgets are
sensitive or focused, and where each widget sits in its window. The host does
the input itself, like a user would: it clicks with a QEMU USB tablet at the
widget's position and types with QEMU `sendkey`. GTK 4 offers no AT-SPI way to
do either (no Component.GrabFocus, no actions on list rows, and Wayland lets
no client synthesize input). Buttons are the exception: they expose a "click"
action, which `act` runs.

Run it as the session's user with DBUS_SESSION_BUS_ADDRESS pointing at that
session's bus.

  atspi_drive.py snapshot APP              JSON list of showing nodes
  atspi_drive.py act APP NAME [ROLE]       run a named widget's click action
  atspi_drive.py frame-action APP ACTION   run one of the window's GActions

APP is a case-insensitive substring of the AT-SPI application name. NAME
matches the accessible name with mnemonic underscores removed, exactly
(case-insensitive) unless it starts with "~", which makes it a substring
match. Snapshot nodes carry "ext": [x, y, width, height] in window
coordinates (GTK 4 on Wayland knows nothing else). Exit status 2 means no
match.
"""

import json
import sys

import gi

gi.require_version("Atspi", "2.0")
from gi.repository import Atspi  # noqa: E402

MAX_NODES = 4000
STATES = ("SHOWING", "VISIBLE", "SENSITIVE", "FOCUSABLE", "FOCUSED", "CHECKED",
          "EDITABLE", "SELECTED", "ENABLED", "ACTIVE")


def norm(text):
    return (text or "").replace("_", "").strip().lower()


def apps(substr):
    desktop = Atspi.get_desktop(0)
    found = []
    for i in range(desktop.get_child_count()):
        app = desktop.get_child_at_index(i)
        if app is not None and substr.lower() in (app.get_name() or "").lower():
            found.append(app)
    return found


def states(node):
    try:
        ss = node.get_state_set()
    except Exception:
        return set()
    return {st.lower() for st in STATES if ss.contains(getattr(Atspi.StateType, st))}


def text_of(node):
    try:
        if node.get_text_iface() is not None:
            return Atspi.Text.get_text(node, 0, -1)
    except Exception:
        pass
    return ""


def actions_of(node):
    try:
        if node.get_action_iface() is None:
            return []
        return [Atspi.Action.get_action_name(node, i) for i in range(Atspi.Action.get_n_actions(node))]
    except Exception:
        return []


def extents_of(node):
    try:
        if node.get_component_iface() is None:
            return None
        r = Atspi.Component.get_extents(node, Atspi.CoordType.WINDOW)
        return [r.x, r.y, r.width, r.height]
    except Exception:
        return None


def walk(node, path="0", depth=0, out=None):
    out = [] if out is None else out
    if node is None or len(out) >= MAX_NODES or depth > 60:
        return out
    st = states(node)
    out.append((node, path, st))
    if depth > 0 and "showing" not in st and "visible" not in st:
        return out
    try:
        n = node.get_child_count()
    except Exception:
        n = 0
    for i in range(n):
        try:
            child = node.get_child_at_index(i)
        except Exception:
            continue
        walk(child, f"{path}.{i}", depth + 1, out)
    return out


def showing_nodes(app_substr):
    found = apps(app_substr)
    if not found:
        print(json.dumps({"error": f"no application matching {app_substr!r}",
                          "apps": [a.get_name() for a in apps("")]}))
        sys.exit(3)
    nodes = []
    for app in found:
        nodes += [(n, p, s) for n, p, s in walk(app) if "showing" in s]
    return nodes


def describe(node, path, st):
    return {
        "path": path,
        "role": node.get_role_name(),
        "name": node.get_name() or "",
        "text": text_of(node)[:200],
        "states": sorted(st),
        "actions": actions_of(node),
        "ext": extents_of(node),
    }


def matches(node, name, role):
    want = norm(name)
    got = norm(node.get_name())
    ok = want[1:] in got if want.startswith("~") else got == want
    return ok and (role is None or node.get_role_name() == role)


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 1
    cmd, app = argv[1], argv[2]
    if cmd == "snapshot":
        print(json.dumps([describe(*n) for n in showing_nodes(app)], indent=1))
        return 0
    if cmd == "act":
        role = argv[4] if len(argv) > 4 else None
        for node, path, st in showing_nodes(app):
            if matches(node, argv[3], role) and "sensitive" in st:
                acts = actions_of(node)
                for preferred in ("click", "press", "activate", "toggle"):
                    if preferred in acts:
                        Atspi.Action.do_action(node, acts.index(preferred))
                        print(json.dumps({"how": f"action:{preferred}", "path": path, "role": node.get_role_name()}))
                        return 0
                print(json.dumps({"how": "none", "path": path, "role": node.get_role_name(), "ext": extents_of(node)}))
                return 0
        print(json.dumps({"error": f"no sensitive showing node named {argv[3]!r}"}))
        return 2
    if cmd == "frame-action":
        # GTK 4 exposes a window's GActions (win.advance, window.toggle-maximized, ...)
        # as AT-SPI actions on the frame; running one is what the bound widget does.
        for node, path, _ in showing_nodes(app):
            if node.get_role_name() == "frame":
                acts = actions_of(node)
                if argv[3] in acts:
                    Atspi.Action.do_action(node, acts.index(argv[3]))
                    print(json.dumps({"how": f"action:{argv[3]}", "path": path}))
                    return 0
        print(json.dumps({"error": f"no frame action {argv[3]!r}"}))
        return 2
    print(__doc__, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
