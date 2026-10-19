#!/usr/bin/env python3
"""Validate RusticQ monitor drafts before using Hyprland's Lua monitor API.
Input is a JSON array on stdin; never invoke a shell or interpolate unchecked text.
The export command writes a standalone snippet; it never overwrites Hyprland config.
"""
import json
import os
import secrets
import math
from pathlib import Path
import re
import subprocess
import sys
import time

PENDING = Path.home() / ".local" / "state" / "rusticq" / "display-pending.json"
ROLLBACK_SECONDS = 15

NAME = re.compile(r'^[a-zA-Z0-9._:-]{1,80}$')
MODE = re.compile(r'^(?:preferred|highres|highrr|maxwidth|\d{3,5}x\d{3,5}(?:@\d{1,3}(?:\.\d{1,6})?(?:Hz)?)?)$')


def validate(raw):
    if not isinstance(raw, list) or not 1 <= len(raw) <= 12:
        raise ValueError('Expected 1–12 connected monitors')
    displays = []
    seen = set()
    for obj in raw:
        if not isinstance(obj, dict):
            raise ValueError('Invalid monitor row')
        name = obj.get('name')
        mode = obj.get('mode', 'preferred')
        if not isinstance(name, str) or not NAME.fullmatch(name) or name in seen:
            raise ValueError('Invalid or duplicate display name')
        seen.add(name)
        if not isinstance(mode, str) or not MODE.fullmatch(mode):
            raise ValueError(f'{name}: unsupported resolution / refresh value')
        x, y = obj.get('x'), obj.get('y')
        scale = obj.get('scale')
        if any(isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) for v in (x, y, scale)):
            raise ValueError(f'{name}: invalid position or scale')
        if not (-30000 <= x <= 30000 and -30000 <= y <= 30000 and 0.5 <= scale <= 3):
            raise ValueError(f'{name}: position or scale out of range')
        width, height = obj.get('width'), obj.get('height')
        if not all(isinstance(n, (int, float)) and not isinstance(n, bool) and 320 <= n <= 16000 for n in (width, height)):
            raise ValueError(f'{name}: invalid logical geometry')
        displays.append(dict(name=name, mode=mode, x=round(x), y=round(y), scale=float(scale),
                             width=width, height=height))
    for i, a in enumerate(displays):
        for b in displays[i + 1:]:
            if (a['x'] < b['x'] + b['width']/b['scale'] - 1 and
                a['x'] + a['width']/a['scale'] > b['x'] + 1 and
                a['y'] < b['y'] + b['height']/b['scale'] - 1 and
                a['y'] + a['height']/a['scale'] > b['y'] + 1):
                raise ValueError(f'Monitors {a["name"]} and {b["name"]} overlap. Move them apart.')
    return displays


def make_lua(displays):
    return '\n'.join('hl.monitor({ output = %s, mode = %s, position = %s, scale = %s })' % (
        json.dumps(d['name']), json.dumps(d['mode']), json.dumps(f'{d["x"]}x{d["y"]}'),
        format(d['scale'], '.3f').rstrip('0').rstrip('.')) for d in displays) + '\n'


def make_keyword_specs(displays):
    specs = []
    for d in displays:
        mode = d['mode'].replace('Hz', '')
        specs.append(f"{d['name']},{mode},{d['x']}x{d['y']},{format(d['scale'], '.3f').rstrip('0').rstrip('.')}")
    return specs


def readback():
    result = subprocess.run(['hyprctl', '-j', 'monitors'], capture_output=True, text=True, timeout=8)
    if result.returncode != 0:
        raise RuntimeError('Monitor commands sent, but readback failed: ' + result.stderr[:250])
    return {m.get('name'): m for m in json.loads(result.stdout)}


def mismatches_for(monitors, active):
    mismatches = []
    for expected in monitors:
        actual = active.get(expected['name'])
        if not actual:
            mismatches.append(expected['name'] + ' not active')
            continue
        if abs(actual.get('x', 0) - expected['x']) > 1 or abs(actual.get('y', 0) - expected['y']) > 1:
            mismatches.append(expected['name'] + ' position unchanged')
        if abs(float(actual.get('scale', 1)) - expected['scale']) > 0.02:
            mismatches.append(expected['name'] + ' scale unchanged')
        if abs(actual.get('width', 0) - expected['width']) > 1 or abs(actual.get('height', 0) - expected['height']) > 1:
            mismatches.append(expected['name'] + ' resolution unchanged')
        frequency = re.search(r'@(\d+(?:\.\d+)?)', expected['mode'])
        if frequency and abs(float(actual.get('refreshRate', 0)) - float(frequency.group(1))) > 1.1:
            mismatches.append(expected['name'] + ' refresh rate unchanged')
    return mismatches


def apply_with_eval(lua):
    for command in lua.splitlines():
        result = subprocess.run(['hyprctl', 'eval', command], capture_output=True, text=True, timeout=8)
        response = (result.stdout + result.stderr).strip()
        if result.returncode != 0 or re.search(r'\b(error|invalid|failed|unknown)\b', response, re.I):
            raise RuntimeError('Hyprland rejected monitor rule: ' + response[:450])


def apply_with_keyword(specs):
    for spec in specs:
        result = subprocess.run(['hyprctl', 'keyword', 'monitor', spec], capture_output=True, text=True, timeout=8)
        response = (result.stdout + result.stderr).strip()
        if result.returncode != 0 or re.search(r'\b(error|invalid|failed|unknown)\b', response, re.I):
            raise RuntimeError('Hyprland keyword monitor failed: ' + response[:450])


def from_active(active):
    """Use the compositor as the source of truth for safe rollback."""
    if isinstance(active, dict):
        values = active.values()
    else:
        values = active
    return [dict(name=str(m['name']), width=m['width'], height=m['height'],
                 x=round(m['x']), y=round(m['y']), scale=float(m['scale']),
                 mode=f"{m['width']}x{m['height']}@{float(m.get('refreshRate', 60)):.2f}")
            for m in values if m.get('name') and m.get('width', 0) > 0]


def apply_live(target):
    """HyprMon-style runtime monitor keyword + Lua alternative for Quattro.

    Verify effective values, never assume 'ok' means Hyprland accepted them.
    """
    errors = []
    methods = [
        ('keyword', lambda: apply_with_keyword(make_keyword_specs(target))),
        ('lua', lambda: apply_with_eval(make_lua(target))),
    ]
    for label, method in methods:
        try:
            method()
            time.sleep(.25)
            mismatches = mismatches_for(target, readback())
            if not mismatches:
                return label
            errors.append(label + ': ' + ', '.join(mismatches))
        except (RuntimeError, subprocess.TimeoutExpired, OSError) as error:
            errors.append(label + ': ' + str(error)[:260])
    raise RuntimeError('Live monitor update failed: ' + ' · '.join(errors))


def pending_read():
    try:
        data = json.loads(PENDING.read_text())
        return data if isinstance(data, dict) else None
    except (OSError, ValueError):
        return None


def pending_write(data):
    PENDING.parent.mkdir(parents=True, exist_ok=True)
    temp = PENDING.with_name(PENDING.name + '.' + secrets.token_hex(6) + '.tmp')
    try:
        with temp.open('x') as handle:
            os.chmod(temp, 0o600)
            json.dump(data, handle)
        temp.replace(PENDING)
    finally:
        temp.unlink(missing_ok=True)


def pending_clear(token=None):
    current = pending_read()
    if current and (token is None or current.get('token') == token):
        PENDING.unlink(missing_ok=True)


def rollback(data):
    baseline = validate(data['baseline'])
    apply_live(baseline)
    return baseline


def watchdog(token):
    time.sleep(ROLLBACK_SECONDS)
    data = pending_read()
    if data and data.get('token') == token:
        try:
            rollback(data)
        except (RuntimeError, OSError, subprocess.TimeoutExpired):
            # Keep the snapshot on disk so user can run `... revert` manually.
            return 1
        pending_clear(token)
    return 0


def launch_watchdog(token):
    subprocess.Popen([sys.executable, str(Path(__file__).resolve()), 'watch', token],
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True,
                     close_fds=True)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'dry-run'
    if action == 'watch':
        if len(sys.argv) != 3 or not re.fullmatch('[0-9a-f]{32}', sys.argv[2]):
            raise ValueError('Invalid watchdog token')
        return dict(ok=watchdog(sys.argv[2]) == 0)
    if action == 'keep':
        if not pending_read():
            return dict(ok=True, message='No pending display update to keep')
        pending_clear()
        return dict(ok=True, message='Display changes kept for this session. Export Lua for persistence.', pending=False)
    if action == 'revert':
        data = pending_read()
        if not data:
            return dict(ok=True, message='No pending display update to revert', pending=False)
        rollback(data)
        pending_clear(data['token'])
        return dict(ok=True, message='Previous monitor layout restored', pending=False)
    if action == 'status':
        return dict(ok=True, pending=bool(pending_read()))
    if action not in ('dry-run', 'apply', 'export'):
        raise ValueError('Unknown action')
    # Quickshell Process keeps stdin open while it runs: json.load(sys.stdin)
    # would wait for EOF forever. Read the single newline-framed JSON request.
    line = sys.stdin.readline(131072)
    if not line or not line.endswith("\n"):
        raise ValueError('Display request was empty, incomplete or too large')
    monitors = validate(json.loads(line))
    if action == 'export':
        target = Path.home() / '.config' / 'rustiq' / 'monitors.lua'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('-- Generated by RusticQ Beta 1; source from Hyprland config to persist.\n' + make_lua(monitors))
        return dict(ok=True, message=f'Exported {target} (does not modify Hyprland config)')
    if action == 'dry-run':
        return dict(ok=True, message='Display layout valid', lua=make_lua(monitors))

    before = readback()
    current = validate(from_active(before))
    if {x['name'] for x in current} != {x['name'] for x in monitors}:
        raise RuntimeError('Connected monitors changed. Refresh before applying.')
    existing = pending_read()
    baseline = validate(existing['baseline']) if existing else current
    if not mismatches_for(monitors, before):
        return dict(ok=True, message='Display settings already active', pending=bool(existing), seconds=max(0, int(ROLLBACK_SECONDS - (time.time() - existing.get('updated', time.time())))) if existing else 0)

    # The original layout is kept until the user presses Keep, and an independent
    # watchdog reverts it even when Settings closes or Quickshell crashes.
    token = secrets.token_hex(16)
    # Arm recovery *before* changing outputs; a helper crash must not leave
    # a changed layout without its original layout on disk.
    pending_write(dict(token=token, baseline=baseline, updated=time.time()))
    try:
        launch_watchdog(token)
        method = apply_live(monitors)
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        try:
            apply_live(baseline)
            pending_clear()
        except (RuntimeError, OSError, subprocess.TimeoutExpired) as revert_error:
            raise RuntimeError(str(error) + '; automatic rollback also failed: ' + str(revert_error))
        raise RuntimeError(str(error) + '; previous layout restored')
    return dict(ok=True, pending=True, seconds=ROLLBACK_SECONDS,
                message=f'Live via {method}. Keep changes within {ROLLBACK_SECONDS}s or they will revert.')


if __name__ == '__main__':
    try:
        print(json.dumps(main()))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError, KeyError) as error:
        print(json.dumps(dict(ok=False, message=str(error))))
        sys.exit(1)
