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
ACTIONS = frozenset(('watch', 'brightness-up', 'brightness-down', 'keyboard-up', 'keyboard-down', 'touchpad-toggle', 'touchpad-on', 'touchpad-off'))


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


def keyboard_stage(level, maximum):
    """Off + up to 3 real hardware brightness stages (not a %)."""
    stages = max(1, min(3, maximum))
    current = max(0, min(maximum, level))
    if current == 0:
        return 0, stages
    return max(1, min(stages, round(current * stages / maximum))), stages


def keyboard_target(level, maximum, direction):
    current, stages = keyboard_stage(level, maximum)
    next_stage = max(0, min(stages, current + direction))
    return round(next_stage * maximum / stages), next_stage, stages


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
                info = dict(kind=kind, device=state[0])
                if kind == 'keyboard':
                    info['stage'], info['stages'] = keyboard_stage(state[1], state[2])
                else:
                    info['percent'] = state[3]
                emit(**info)
        previous = current


def change_backlight(kind, direction):
    devices = hardware_devices(kind)
    for device in devices:
        state = read_level(device)
        if not state:
            continue
        level, maximum, _ = state
        if kind == 'keyboard':
            desired, stage, stages = keyboard_target(level, maximum, direction)
        else:
            step = max(1, round(maximum * 0.05))
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
        if kind == 'keyboard':
            stage, stages = keyboard_stage(updated[0], updated[1]) if updated else keyboard_stage(desired, maximum)
            emit(ok=True, kind='keyboard', stage=stage, stages=stages)
        else:
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
        data = json.loads(TOUCHPAD_STATUS.read_text(encoding='utf-8'))
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def omarchy_touchpad_disabled(device):
    """Respect Omarchy Quattro's persisted disabled-name file when present.

    This is only a read; RusticQ does not delete or overwrite Omarchy's state.
    """
    marker = Path.home() / '.local/state/omarchy/toggles/hypr/touchpad-disabled-name'
    if not marker.is_file() or marker.is_symlink():
        return False
    try:
        return marker.read_text(encoding='utf-8').strip() == device
    except (OSError, UnicodeError):
        return False


def _run_hypr(args):
    return subprocess.run(args, capture_output=True, text=True, timeout=5, check=False)


def _accepted_hypr(proc):
    text = (proc.stdout + '\n' + proc.stderr).strip().lower()
    return proc.returncode == 0 and not any(s in text for s in ('error', 'invalid', 'unknown', 'failed', 'exception'))


def _set_touchpad(device, enabled):
    # Names originate from hardware descriptors. Never pass them to a shell,
    # and use JSON quoting for Lua to prevent device-name injection.
    if not device or len(device) > 256 or any(ord(c) < 32 or ord(c) == 127 for c in device):
        raise ValueError('Unsafe touchpad name returned by Hyprland')
    # Prefer Quattro's documented hl.device API. Other Hyprland builds may
    # expose the classic device[name]:enabled keyword instead.
    script = 'hl.device({ name = ' + json.dumps(device, ensure_ascii=True) + ', enabled = ' + ('true' if enabled else 'false') + ' })'
    proc = _run_hypr(['hyprctl', 'eval', script])
    if not _accepted_hypr(proc):
        proc = _run_hypr(['hyprctl', 'keyword', 'device[' + device + ']:enabled', 'true' if enabled else 'false'])
    if not _accepted_hypr(proc):
        raise ValueError('Hyprland rejected touchpad change: ' + (proc.stderr or proc.stdout or 'unsupported device setting')[-160:])


def change_touchpad(action='touchpad-toggle'):
    result = _run_hypr(['hyprctl', '-j', 'devices'])
    if result.returncode:
        raise ValueError('Cannot read Hyprland input devices: ' + result.stderr[-120:])
    try:
        pads = touchpads_from_devices(json.loads(result.stdout))
    except (ValueError, TypeError) as exc:
        raise ValueError('Invalid Hyprland device inventory') from exc
    if not pads:
        raise ValueError('No touchpad found; external mouse is not disabled')
    saved = previous_touchpad_status()
    device, reported = pads[0]
    if isinstance(reported, bool):
        current = reported
    elif isinstance(reported, int) and reported in (0, 1):
        current = bool(reported)
    elif omarchy_touchpad_disabled(device):
        current = False
    elif saved.get('device') == device and isinstance(saved.get('enabled'), bool):
        current = saved['enabled']
    else:
        # Hyprland often omits `enabled` in devices -j. Without an Omarchy
        # disable marker, the default configuration is enabled. Use that
        # baseline and keep our own toggles consistent during this session.
        current = True
    desired = not current if action == 'touchpad-toggle' else action == 'touchpad-on'
    if action not in ('touchpad-toggle', 'touchpad-on', 'touchpad-off'):
        raise ValueError('Invalid touchpad operation')
    if current != desired:
        _set_touchpad(device, desired)
    RUNTIME.mkdir(parents=True, exist_ok=True, mode=0o700)
    TOUCHPAD_STATUS.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    TOUCHPAD_STATUS.write_text(json.dumps({'device': device, 'enabled': desired}) + '\n', encoding='utf-8')
    TOUCHPAD_STATUS.chmod(0o600)
    emit(ok=True, kind='touchpad', enabled=desired, device=device)


def main(args):
    if len(args) != 1 or args[0] not in ACTIONS:
        raise ValueError('Invalid OSD hardware action')
    action = args[0]
    if action == 'watch':
        return watch()
    if action in ('touchpad-toggle', 'touchpad-on', 'touchpad-off'):
        change_touchpad(action)
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
