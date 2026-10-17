#!/usr/bin/env python3
"""Validate RusticQ monitor drafts before using Hyprland's Lua monitor API.
Input is a JSON array on stdin; never invoke a shell or interpolate unchecked text.
The export command writes a standalone snippet; it never overwrites Hyprland config.
"""
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import time

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


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'dry-run'
    if action not in ('dry-run', 'apply', 'export'):
        raise ValueError('Unknown action')
    raw = json.load(sys.stdin)
    monitors = validate(raw)
    lua = make_lua(monitors)
    if action == 'export':
        target = Path.home() / '.config' / 'rustiq' / 'monitors.lua'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text('-- Generated by RusticQ Beta 1; source explicitly in Hyprland config to persist.\n' + lua)
        return dict(ok=True, message=f'Exported {target} (does not modify Hyprland config)')
    if action == 'apply':
        tried = []
        eval_error = None
        try:
            apply_with_eval(lua)
            tried.append('lua')
        except RuntimeError as e:
            eval_error = str(e)
        time.sleep(0.45)
        active = readback()
        mismatches = mismatches_for(monitors, active)
        # Lua-enabled Omarchy rejects the legacy keyword parser, sometimes with exit code 0.
        # Do not report a false success or mask a Lua error with the rejected fallback.
        parser = subprocess.run(['hyprctl', 'version'], capture_output=True, text=True, timeout=8)
        quattro_lua = 'lua' in (parser.stdout + parser.stderr).lower() or (Path.home() / '.config/hypr/hyprland.lua').exists()
        if (eval_error or mismatches) and not quattro_lua:
            apply_with_keyword(make_keyword_specs(monitors))
            tried.append('keyword')
            time.sleep(0.45)
            active = readback()
            mismatches = mismatches_for(monitors, active)
        if mismatches:
            detail = ', '.join(mismatches)
            if eval_error:
                detail = eval_error + ' · ' + detail
            raise RuntimeError('Hyprland did not apply: ' + detail + '. Export Lua for persistence or use nwg-displays.')
        method = ' + '.join(tried) if tried else 'readback'
        if eval_error and 'keyword' in tried:
            return dict(ok=True, message='Verified via keyword fallback: layout changed in running session. Export Lua to persist.')
        return dict(ok=True, message='Verified: layout changed in running session via ' + method + '. Export Lua to persist.')
    return dict(ok=True, message='Draft validation passed', lua=lua)


if __name__ == '__main__':
    try:
        print(json.dumps(main()))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired, json.JSONDecodeError) as e:
        print(json.dumps(dict(ok=False, message=str(e))))
        sys.exit(1)
