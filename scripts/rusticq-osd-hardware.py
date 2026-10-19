#!/usr/bin/env python3
"""Unprivileged hardware-state watcher and safe Hyprland touchpad controls.

Watch reads kernel sysfs files directly: no recurring subprocesses or shell
commands. Controls require explicit RusticQ shortcut actions, never disable all
mouse devices by default. JSON on stdout, diagnostics on stderr.
"""
import json
import math
import os
import re
import subprocess
import sys
import time
from pathlib import Path

BACKLIGHT = Path('/sys/class/backlight')
LEDS = Path('/sys/class/leds')
RUNTIME = Path(os.environ.get('XDG_RUNTIME_DIR', '/run/user/%d' % os.getuid())) / 'rusticq'
TOUCHPAD_STATUS = RUNTIME / 'touchpad-status.json'
ACTIONS = frozenset(('watch', 'brightness-up', 'brightness-down', 'keyboard-up', 'keyboard-down', 'touchpad-toggle'))


def emit(**data):
    print(json.dumps(data, ensure_ascii=False), flush=True)


def hardware_devices(kind):
    folder = BACKLIGHT if kind == 'brightness' else LEDS
    if not folder.is_dir():
        return []
    try:
        devices = sorted(folder.iterdir())
    except OSError:
        return []
    if kind == 'keyboard':
        devices = [p for p in devices if 'kbd_backlight' in p.name.lower() or 'keyboard_backlight' in p.name.lower()]
    return [p for p in devices if (p / 'brightness').is_file() and (p / 'max_brightness').is_file()]


def read_level(device):
    try:
        level = int((device / 'brightness').read_text().strip())
        maximum = int((device / 'max_brightness').read_text().strip())
        if maximum <= 0:
            return None
        return level, maximum, int(round(level * 100 / maximum))
    except (OSError, ValueError, OverflowError):
        return None


def snapshot():
    output = {}
    for kind in ('brightness', 'keyboard'):
        candidates = hardware_devices(kind)
        for dev in candidates:
            values = read_level(dev)
            if values:
                output[kind] = (dev.name, *values)
                break
    return output


def watch(interval=0.60):
    previous = snapshot()
    if not previous:
        return 0  # Nothing to watch, so no background process consumes RAM.
    while True:
        time.sleep(interval)
        current = snapshot()
        for kind, state in current.items():
            if kind in previous and state != previous[kind]:
                emit(kind=kind, percent=state[3], device=state[0])
        previous = current


def change_backlight(kind, direction):
    devices = hardware_devices(kind)
    for device in devices:
        state = read_level(device)
        if not state:
            continue
        level, maximum, _ = state
        step = max(1, round(maximum * (0.05 if kind == 'brightness' else 0.15)))
        desired = max(0, min(maximum, level + direction * step))
        if kind == 'brightness' and desired == 0 and direction < 0:
            desired = max(1, round(maximum * 0.01))
        # brightnessctl already supports system udev permissions. No sudo or
        # writes to protected sysfs attempted by the GUI process.
        result = subprocess.run(['brightnessctl', '-d', device.name, 'set', str(desired)],
                                text=True, capture_output=True, timeout=8, check=False)
        if result.returncode:
            raise ValueError((result.stderr or result.stdout or 'Backlight permission denied').strip()[-210:])
        updated = read_level(device)
        emit(ok=True, kind=kind, percent=updated[2] if updated else int(desired * 100 / maximum))
        return
    raise ValueError('No supported %s device found' % ('keyboard backlight' if kind == 'keyboard' else 'screen backlight'))


def touchpads_from_devices(raw):
    """Only devices clearly categorized as a touchpad may be disabled."""
    mice = raw.get('mice', []) if isinstance(raw, dict) else []
    found = []
    for item in mice:
        if not isinstance(item, dict):
            continue
        name = str(item.get('name', '')).strip()
        if 'touchpad' in name.lower() or 'trackpad' in name.lower():
            if name and '\n' not in name and '[' not in name and ']' not in name:
                found.append((name, item.get('enabled')))
    return found


def previous_touchpad_status():
    try:
        return json.loads(TOUCHPAD_STATUS.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return {}


def change_touchpad():
    result = subprocess.run(['hyprctl', '-j', 'devices'], text=True, capture_output=True,
                            timeout=5, check=False)
    if result.returncode:
        raise ValueError('Cannot read Hyprland input devices: ' + result.stderr[-120:])
    pads = touchpads_from_devices(json.loads(result.stdout))
    if not pads:
        raise ValueError('No touchpad found; external mouse is not disabled')
    saved = previous_touchpad_status()
    device, current = pads[0]
    if isinstance(current, bool):
        enabled = current
    elif isinstance(current, int) and current in (0, 1):
        enabled = bool(current)
    elif saved.get('device') == device and isinstance(saved.get('enabled'), bool):
        enabled = saved['enabled']
    else:
        # Device state not exposed: do not risk accidentally disabling unknown
        # devices based on a guessed state; require visible native status.
        raise ValueError('Hyprland did not expose touchpad enabled status; device unchanged')
    new_state = not enabled
    # Classic Hyprland uses device[name]:enabled. Quattro Lua may require eval.
    keyword = 'device[' + device + ']:enabled'
    proc = subprocess.run(['hyprctl', 'keyword', keyword, 'true' if new_state else 'false'],
                          capture_output=True, text=True, timeout=5, check=False)
    if proc.returncode or 'error' in proc.stdout.lower():
        lua_name = json.dumps(device)
        lua_code = 'hl.device({name = ' + lua_name + ', enabled = ' + ('true' if new_state else 'false') + '})'
        proc = subprocess.run(['hyprctl', 'eval', lua_code], capture_output=True, text=True, timeout=5, check=False)
    if proc.returncode or 'error' in proc.stdout.lower():
        raise ValueError('Hyprland rejected touchpad change: ' + (proc.stderr or proc.stdout)[-160:])
    RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
    TOUCHPAD_STATUS.write_text(json.dumps({'device': device, 'enabled': new_state}) + '\n', encoding='utf-8')
    TOUCHPAD_STATUS.chmod(0o600)
    emit(ok=True, kind='touchpad', enabled=new_state, device=device)


def main(args):
    if len(args) != 1 or args[0] not in ACTIONS:
        raise ValueError('Invalid OSD hardware action')
    action = args[0]
    if action == 'watch':
        return watch()
    if action == 'touchpad-toggle':
        change_touchpad()
        return 0
    kind, direction = action.split('-', 1)
    change_backlight(kind, 1 if direction == 'up' else -1)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, subprocess.TimeoutExpired) as exc:
        emit(ok=False, message=str(exc)[:180])
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(0)
