#!/usr/bin/env python3
"""Read actual Hyprland GUI windows; focus a vetted address on request.
No shell interpolation, no arbitrary command execution, no background services.
"""
import json
import re
import subprocess
import sys

ADDRESS = re.compile(r"^(?:0x)?[0-9a-fA-F]{6,}$")


def parse_clients(raw):
    if not isinstance(raw, list):
        raise ValueError("Hyprland clients response must be a JSON array")
    by_class = {}
    for client in raw:
        if not isinstance(client, dict) or client.get("mapped") is False:
            continue
        app = str(client.get("class") or client.get("initialClass") or "").strip()
        title = str(client.get("title") or client.get("initialTitle") or "").strip()
        address = str(client.get("address") or "").strip()
        if not app or app.casefold() in ("quickshell", "rustiq") or not ADDRESS.fullmatch(address):
            continue
        address = "0x" + address.removeprefix("0x")
        focus = client.get("focusHistoryID", 10000)
        try:
            focus = int(focus)
        except (TypeError, ValueError):
            focus = 10000
        key = app.casefold()
        record = {"appId": app, "title": title or app, "address": address,
                  "active": focus == 0, "focusOrder": focus}
        previous = by_class.get(key)
        if previous is None or focus < previous["focusOrder"]:
            by_class[key] = record
    return sorted(by_class.values(), key=lambda a: (a["focusOrder"], a["appId"].lower()))


def list_apps():
    result = subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True, timeout=8)
    if result.returncode != 0:
        raise RuntimeError("Cannot query Hyprland clients: " + result.stderr.strip()[:220])
    return {"ok": True, "apps": parse_clients(json.loads(result.stdout))}


def focus_window(address):
    if not ADDRESS.fullmatch(address):
        raise ValueError("Invalid Hyprland window address")
    address = "0x" + address.removeprefix("0x")
    # Current Hyprland Lua IPC (Omarchy): dispatch is shorthand for hl.dispatch(...).
    lua = 'hl.dsp.focus({ window = "address:' + address + '" })'
    result = subprocess.run(["hyprctl", "dispatch", lua], capture_output=True, text=True, timeout=8)
    output = (result.stdout + result.stderr).strip()
    if result.returncode != 0 or re.search(r"\b(error|invalid|failed|not found|expected)\b", output, re.I):
        # Classic Hyprland compatibility, without using a shell or running user text.
        fallback = subprocess.run(["hyprctl", "dispatch", "focuswindow", "address:" + address],
                                  capture_output=True, text=True, timeout=8)
        output = (fallback.stdout + fallback.stderr).strip()
        if fallback.returncode != 0 or re.search(r"\b(error|invalid|failed|not found|expected)\b", output, re.I):
            raise RuntimeError("Window focus not accepted by Hyprland: " + output[:220])
    return {"ok": True, "message": "Window focus requested"}


def main(args):
    if args == ["list"]:
        return list_apps()
    if len(args) == 2 and args[0] == "focus":
        return focus_window(args[1])
    raise ValueError("Usage: rustiq-running-apps.py list | focus ADDRESS")


if __name__ == "__main__":
    try:
        print(json.dumps(main(sys.argv[1:])))
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError, subprocess.TimeoutExpired) as error:
        print(json.dumps({"ok": False, "error": str(error), "apps": []}))
        sys.exit(1)
