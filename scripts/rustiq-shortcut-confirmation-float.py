#!/usr/bin/env python3
"""Place RusticQ's package confirmation on the *Settings* workspace.

Targets only two exact-title, address-validated Hyprland clients. Does not
change active workspace, pin windows, install rules, or edit user config.
Supports Lua-backed Hyprland / Omarchy Quattro and legacy Hyprland.
"""
import json
import re
import shutil
import subprocess
import time

SETTINGS_TITLE = 'RusticQ · Settings'
CONFIRM_TITLE = 'RusticQ · Shortcut Backup Confirmation'
ADDRESS = re.compile(r'0x[0-9a-fA-F]{4,16}\Z')


def get_clients():
    result = subprocess.run(['hyprctl', '-j', 'clients'], capture_output=True,
                            text=True, timeout=3)
    if result.returncode != 0:
        raise RuntimeError(result.stderr[:180])
    result = json.loads(result.stdout)
    return result if isinstance(result, list) else []


def find_client(clients, title):
    return next((c for c in clients if isinstance(c, dict) and
                 c.get('title') == title and
                 isinstance(c.get('address'), str) and
                 ADDRESS.fullmatch(c['address'])), None)


def workspace(client):
    ws = client.get('workspace', {})
    if not isinstance(ws, dict):
        return None
    value = ws.get('id')
    if type(value) is int and value > 0:
        return value
    return None


def dispatch_lua(expression):
    result = subprocess.run(['hyprctl', 'dispatch', expression],
                            capture_output=True, text=True, timeout=3)
    output = (result.stdout + result.stderr).lower()
    return result.returncode == 0 and not any(x in output for x in ('error', 'invalid', 'failed', 'unknown'))


def dispatch_legacy(command, argument):
    result = subprocess.run(['hyprctl', 'dispatch', command, argument],
                            capture_output=True, text=True, timeout=3)
    output = (result.stdout + result.stderr).lower()
    return result.returncode == 0 and not any(x in output for x in ('error', 'invalid', 'failed', 'unknown'))


def arrange(settings, confirm):
    addr = confirm['address']
    selector = 'address:' + addr
    literal = json.dumps(selector)
    if confirm.get('floating') is not True:
        if not (dispatch_lua('hl.dsp.window.float({ action = "set", window = ' + literal + ' })') or
                dispatch_legacy('togglefloating', 'address:' + addr)):
            return False

    target_ws = workspace(settings)
    if target_ws is not None and workspace(confirm) != target_ws:
        move = 'hl.dsp.window.move({ window = ' + literal + ', workspace = ' + str(target_ws) + ', follow = false })'
        moved = dispatch_lua(move)
        if moved:
            # Some Lua-capable builds return "ok" even when no window was moved.
            time.sleep(.09)
            latest = find_client(get_clients(), CONFIRM_TITLE)
            moved = bool(latest and workspace(latest) == target_ws)
        if not moved:
            moved = dispatch_legacy('movetoworkspacesilent', str(target_ws) + ',address:' + addr)
        if not moved:
            return False
        time.sleep(.09)
        latest = find_client(get_clients(), CONFIRM_TITLE)
        if not latest or workspace(latest) != target_ws:
            return False

    size = confirm.get('size')
    if not isinstance(size, list) or len(size) < 2 or abs(size[0] - 550) > 24 or abs(size[1] - 418) > 72:
        lua = 'hl.dsp.window.resize({ window = ' + literal + ', x = 550, y = 418, relative = false })'
        dispatch_lua(lua) or dispatch_legacy('resizewindowpixel', 'exact 550 418,address:' + addr)
    dispatch_lua('hl.dsp.window.center({ window = ' + literal + ' })') or dispatch_legacy('centerwindow', 'address:' + addr)
    return True


def main():
    if not shutil.which('hyprctl'):
        return 0
    for _ in range(14):
        try:
            clients = get_clients()
            settings = find_client(clients, SETTINGS_TITLE)
            confirm = find_client(clients, CONFIRM_TITLE)
            if settings and confirm:
                return 0 if arrange(settings, confirm) else 1
        except (ValueError, OSError, subprocess.TimeoutExpired, RuntimeError):
            pass
        time.sleep(.18)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
