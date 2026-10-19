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
DEFAULT_WIDTH = 1100
DEFAULT_HEIGHT = 760


def target_size(client):
    """Clamp preferred floating size to this window's actual monitor."""
    try:
        result = subprocess.run(["hyprctl", "-j", "monitors"],
                                capture_output=True, text=True, timeout=3)
        if result.returncode != 0:
            return DEFAULT_WIDTH, DEFAULT_HEIGHT
        monitors = json.loads(result.stdout)
        if not isinstance(monitors, list):
            return DEFAULT_WIDTH, DEFAULT_HEIGHT
        for monitor in monitors:
            if not isinstance(monitor, dict):
                continue
            same_id = (type(client.get("monitor")) is int and
                       client["monitor"] == monitor.get("id"))
            same_name = (isinstance(client.get("monitor"), str) and
                         client["monitor"] == monitor.get("name"))
            if not (same_id or same_name):
                continue
            scale = monitor.get("scale", 1)
            width, height = monitor.get("width"), monitor.get("height")
            if not all(isinstance(v, (int, float)) and not isinstance(v, bool)
                       for v in [scale, width, height]) or scale <= 0:
                break
            # Hyprland reports physical pixels; window geometry is logical.
            logical_width = int(width / scale)
            logical_height = int(height / scale)
            return (max(600, min(DEFAULT_WIDTH, logical_width - 64)),
                    max(480, min(DEFAULT_HEIGHT, logical_height - 88)))
    except (OSError, subprocess.TimeoutExpired, ValueError, json.JSONDecodeError):
        pass
    return DEFAULT_WIDTH, DEFAULT_HEIGHT


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

    target_width, target_height = target_size(client)
    dimensions = client.get("size")
    size_matches = (isinstance(dimensions, list) and len(dimensions) >= 2
                    and all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in dimensions[:2])
                    and abs(dimensions[0] - target_width) <= 12
                    and abs(dimensions[1] - target_height) <= 12)
    # Initial size can be wrong after Hyprland tiles a FloatingWindow.
    # Resize only on opening, leaving normal interactive resize unrestricted.
    if not size_matches:
        if not dispatch_ok('hl.dsp.window.resize({ ' + selector + ', x = '
                           + str(target_width) + ', y = ' + str(target_height)
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
