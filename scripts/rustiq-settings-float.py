#!/usr/bin/env python3
"""Ensure only RusticQ Settings opens as a compact floating Hyprland window.

This runs once each time Settings is opened. It does not install compositor
rules or alter other windows. After launch users can freely move/resize it.
"""
import json
import re
import shutil
import subprocess
import time

TITLE = "RusticQ · Settings"
ADDRESS = re.compile(r"0x[0-9a-fA-F]{4,16}\Z")
DEFAULT_WIDTH = 940
DEFAULT_HEIGHT = 600


def find_settings_window(clients):
    if not isinstance(clients, list):
        return None
    for client in clients:
        if not isinstance(client, dict):
            continue
        address = client.get("address", "")
        if client.get("title") == TITLE and isinstance(address, str) and ADDRESS.fullmatch(address):
            return client
    return None


def dispatch(expression):
    return subprocess.run(["hyprctl", "dispatch", expression],
                          capture_output=True, text=True, timeout=3)


def dispatch_ok(expression):
    result = dispatch(expression)
    output = (result.stdout + result.stderr).lower()
    return result.returncode == 0 and "error" not in output and "failed" not in output


def ensure_float(client):
    """Float, size, then center one validated window, not the active window."""
    address = client.get("address")
    if not isinstance(address, str) or not ADDRESS.fullmatch(address):
        return False
    selector = 'window = "address:' + address + '"'
    was_floating = client.get("floating") is True
    if not was_floating:
        if not dispatch_ok('hl.dsp.window.float({ action = "set", ' + selector + ' })'):
            return False

    dimensions = client.get("size")
    size_matches = (isinstance(dimensions, list) and len(dimensions) >= 2
                    and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in dimensions[:2])
                    and abs(dimensions[0] - DEFAULT_WIDTH) <= 12
                    and abs(dimensions[1] - DEFAULT_HEIGHT) <= 12)
    # Initial size can be wrong after Hyprland tiles a FloatingWindow.
    # Resize only on opening, leaving normal interactive resize unrestricted.
    if not size_matches:
        if not dispatch_ok('hl.dsp.window.resize({ ' + selector + ', x = '
                           + str(DEFAULT_WIDTH) + ', y = ' + str(DEFAULT_HEIGHT)
                           + ', relative = false })'):
            return False
        if not dispatch_ok('hl.dsp.window.center({ ' + selector + ' })'):
            return False
    elif not was_floating:
        if not dispatch_ok('hl.dsp.window.center({ ' + selector + ' })'):
            return False
    return True


def main():
    if not shutil.which("hyprctl"):
        return 0
    for _ in range(8):
        try:
            result = subprocess.run(["hyprctl", "-j", "clients"],
                                    capture_output=True, text=True, timeout=3)
            if result.returncode == 0:
                client = find_settings_window(json.loads(result.stdout))
                if client:
                    return 0 if ensure_float(client) else 1
        except (OSError, subprocess.TimeoutExpired, ValueError, json.JSONDecodeError):
            pass
        time.sleep(0.20)
    return 0  # Hyprland absent or the window closed before it was discovered.


if __name__ == "__main__":
    raise SystemExit(main())
