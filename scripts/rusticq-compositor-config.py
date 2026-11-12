#!/usr/bin/env python3
"""Risk-limited graphical compositor config backend for RusticQ Beta 3.

Edits ONLY RusticQ-owned blocks inside the user's own config. Original lines,
Omarchy defaults and unrelated include files are never rewritten or parsed away.
Every apply requires a preview fingerprint; validated writes are rollback-safe.
"""
import argparse
import base64
import difflib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time

HOME = Path.home()
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME') or HOME / '.config')
STATE = Path(os.environ.get('XDG_STATE_HOME') or HOME / '.local/state') / 'rusticq' / 'compositor-config'
SECTIONS = ('autostart', 'appearance', 'input', 'monitors')
LUA_SECTIONS = {'autostart': 'autostart.lua', 'appearance': 'looknfeel.lua',
                'input': 'input.lua', 'monitors': 'monitors.lua'}
HYPR_REQUIRED = {'autostart': 'hypr.autostart', 'appearance': 'hypr.looknfeel',
                 'input': 'hypr.input', 'monitors': 'hypr.monitors'}
BEGIN = '-- RUSTICQ COMPOSITOR CONFIG:'
END = '-- END RUSTICQ COMPOSITOR CONFIG:'


def digest(contents):
    return hashlib.sha256(contents).hexdigest()


def compositor():
    desktop = (os.environ.get('XDG_CURRENT_DESKTOP', '') + ':' + os.environ.get('XDG_SESSION_DESKTOP', '')).lower()
    hs, ns = bool(os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')), bool(os.environ.get('NIRI_SOCKET'))
    if hs and ns:
        return 'ambiguous'
    if hs:
        return 'hyprland'
    if ns:
        return 'niri'
    has_h = bool(re.search(r'(^|[:;,])\s*hyprland\s*($|[:;,])', desktop))
    has_n = bool(re.search(r'(^|[:;,])\s*niri\s*($|[:;,])', desktop))
    return ('ambiguous' if has_h and has_n else 'hyprland' if has_h else 'niri' if has_n else 'unknown')


def path_for(backend, section):
    if backend == 'hyprland':
        return CONFIG / 'hypr' / LUA_SECTIONS[section]
    if backend == 'niri':
        return Path(os.environ.get('NIRI_CONFIG') or CONFIG / 'niri/config.kdl')
    raise ValueError('Unknown compositor; no config will be written')


def supported(backend, section):
    return backend == 'hyprland' or (backend == 'niri' and section in ('autostart', 'appearance'))


def check_path(path):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError('Symlinked configuration path is not editable: ' + str(path))
    if not path.is_file():
        raise ValueError('User compositor file is missing: ' + str(path))
    if path.stat().st_size > 2_000_000:
        raise ValueError('Configuration exceeds safe edit limit (2 MB)')
    return path.read_bytes()


def require_loaded(backend, section):
    if not supported(backend, section):
        raise ValueError('This section is read-only for ' + backend + ' until its schema is supported')
    target = path_for(backend, section)
    before = check_path(target)
    if backend == 'hyprland':
        main = CONFIG / 'hypr/hyprland.lua'
        if not main.is_file() or main.is_symlink():
            raise ValueError('Missing safe Omarchy Lua entrypoint: ' + str(main))
        source = main.read_text(encoding='utf-8')
        required = HYPR_REQUIRED[section]
        if not re.search(r'(?m)^\s*require\s*\(\s*[\'\"]' + re.escape(required) + r'[\'\"]\s*\)', source):
            raise ValueError('Omarchy entrypoint does not load ' + required + '; refusing an ineffective edit')
    elif backend == 'niri':
        if not shutil.which('niri'):
            raise ValueError('Niri binary is unavailable: cannot validate KDL changes safely')
    return target, before


def marker(backend, section):
    if backend == 'hyprland':
        return BEGIN + section, END + section
    return '// RUSTICQ COMPOSITOR CONFIG:' + section, '// END RUSTICQ COMPOSITOR CONFIG:' + section


def block_span(text, backend, section):
    start, stop = marker(backend, section)
    if text.count(start + '\n') != text.count(stop + '\n') or text.count(start + '\n') > 1:
        raise ValueError('Managed block markers are inconsistent; inspect config manually')
    if start + '\n' not in text:
        return None
    b = text.index(start + '\n')
    e = text.index(stop + '\n', b) + len(stop) + 1
    if e <= b:
        raise ValueError('Malformed managed block')
    return b, e


def canonical(values):
    return json.dumps(values, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


def validate(backend, section, values):
    if not isinstance(values, dict) or not supported(backend, section):
        raise ValueError('Unsupported configuration section')
    if section == 'autostart':
        entries = values.get('commands', [])
        if not isinstance(entries, list) or len(entries) > 24:
            raise ValueError('Autostart supports up to 24 commands')
        for item in entries:
            if not isinstance(item, str) or not item.strip() or len(item) > 400 or any(ord(c) < 32 for c in item):
                raise ValueError('Autostart commands must be single lines (1–400 characters)')
        return {'commands': [e.strip() for e in entries]}
    if section == 'appearance':
        fields = {'gaps_in': (0, 50), 'gaps_out': (0, 80)}
        if backend == 'hyprland':
            fields['rounding'] = (0, 30)
        result = {}
        for name, bounds in fields.items():
            val = values.get(name)
            if type(val) is not int or not bounds[0] <= val <= bounds[1]:
                raise ValueError(name + ': expected integer ' + str(bounds))
            result[name] = val
        return result
    if section == 'input':
        layout = values.get('kb_layout', '')
        if not isinstance(layout, str) or not re.fullmatch(r'[a-z0-9_,+-]{1,24}', layout):
            raise ValueError('Invalid keyboard layout identifier')
        follow = values.get('follow_mouse')
        natural = values.get('natural_scroll')
        if type(follow) is not bool or type(natural) is not bool:
            raise ValueError('Input switches must be true or false')
        return {'kb_layout': layout, 'follow_mouse': follow, 'natural_scroll': natural}
    if section == 'monitors':
        output = values.get('output', '')
        mode = values.get('mode', '')
        position = values.get('position', '')
        scale = values.get('scale')
        if not isinstance(output, str) or not re.fullmatch(r'[A-Za-z0-9._-]{1,55}', output):
            raise ValueError('Invalid monitor output name')
        if not isinstance(mode, str) or not re.fullmatch(r'(preferred|[0-9]{3,5}x[0-9]{3,5}@[0-9.]{2,8})', mode):
            raise ValueError('Invalid monitor mode')
        if not isinstance(position, str) or not re.fullmatch(r'(auto|-?[0-9]{1,5}x-?[0-9]{1,5})', position):
            raise ValueError('Invalid monitor position')
        if type(scale) not in (int, float) or not 0.5 <= scale <= 3.0:
            raise ValueError('Monitor scale must be 0.5–3')
        return dict(output=output, mode=mode, position=position, scale=float(scale))
    raise ValueError('Unsupported section')


def lua_string(s):
    # Lua decimal escapes, quoted and ASCII-safe (no JSON \uXXXX escapes).
    raw = []
    for b in s.encode('utf-8'):
        if b == 34: raw.append('\\"')
        elif b == 92: raw.append('\\\\')
        elif b < 32 or b == 127 or b >= 128: raw.append('\\%03d' % b)
        else: raw.append(chr(b))
    return '"' + ''.join(raw) + '"'


def kdl_string(s):
    return json.dumps(s, ensure_ascii=False)


def generate(backend, section, values):
    data = validate(backend, section, values)
    hdr, tail = marker(backend, section)
    meta = base64.b64encode(canonical(data).encode('utf-8')).decode('ascii')
    comment = '--' if backend == 'hyprland' else '//'
    lines = [hdr, comment + ' rusticq-meta:' + meta, comment + ' Generated by RusticQ. Edit in Settings > Compositor.']
    if section == 'autostart' and backend == 'hyprland':
        if data['commands']:
            lines += ['hl.on("hyprland.start", function()']
            for command in data['commands']:
                lines += ['    hl.exec_cmd(' + lua_string(command) + ')']
            lines += ['end)']
    elif section == 'autostart':
        lines += ['spawn-sh-at-startup ' + kdl_string(item) for item in data['commands']]
    elif section == 'appearance' and backend == 'hyprland':
        lines += ['hl.config({', '    general = { gaps_in = %d, gaps_out = %d },' % (data['gaps_in'], data['gaps_out']),
                  '    decoration = { rounding = %d },' % data['rounding'], '})']
    elif section == 'appearance':
        # Niri's layout gap; gaps_in maps to its one supported gap setting.
        lines += ['layout {', '    gaps %d' % data['gaps_in'], '}']
    elif section == 'input':
        lines += ['hl.config({', '    input = {', '        kb_layout = ' + lua_string(data['kb_layout']) + ',',
                  '        follow_mouse = %d,' % (1 if data['follow_mouse'] else 0),
                  '        touchpad = { natural_scroll = ' + ('true' if data['natural_scroll'] else 'false') + ' },',
                  '    },', '})']
    elif section == 'monitors':
        lines += ['hl.monitor({ output = %s, mode = %s, position = %s, scale = %s })' % (
            lua_string(data['output']), lua_string(data['mode']), lua_string(data['position']), data['scale'])]
    return '\n'.join(lines + [tail, ''])


def replace_block(before, backend, section, values):
    source = before.decode('utf-8')
    fragment = generate(backend, section, values)
    loc = block_span(source, backend, section)
    if loc is None:
        if source and not source.endswith('\n'):
            source += '\n'
        return (source + '\n' + fragment).encode('utf-8')
    a, b = loc
    return (source[:a] + fragment + source[b:]).encode('utf-8')


def metadata_from_block(before, backend, section):
    text = before.decode('utf-8')
    loc = block_span(text, backend, section)
    if loc is None:
        return None
    snippet = text[loc[0]:loc[1]]
    match = re.search(r'(?m)^(?:--|//) rusticq-meta:([A-Za-z0-9+/=]+)$', snippet)
    if not match:
        return None
    try:
        return validate(backend, section, json.loads(base64.b64decode(match.group(1), validate=True)))
    except (ValueError, TypeError, KeyError):
        return None


def defaults(section, backend):
    if section == 'autostart': return {'commands': []}
    if section == 'appearance': return {'gaps_in': 5, 'gaps_out': 10, **({'rounding': 8} if backend == 'hyprland' else {})}
    if section == 'input': return {'kb_layout': 'us', 'follow_mouse': True, 'natural_scroll': False}
    if section == 'monitors': return {'output': 'eDP-1', 'mode': 'preferred', 'position': 'auto', 'scale': 1.0}
    raise ValueError('Unsupported section')


def fingerprint(backend, section, before, values):
    return digest(backend.encode() + b'\0' + section.encode() + b'\0' + before + b'\0' + canonical(values).encode())


def summary(backend=None):
    backend = backend or compositor()
    result = {'ok': True, 'backend': backend, 'editable': {}, 'sections': {},
              'backup_dir': str(STATE / 'history'), 'other_options': ['keybindings: Settings > Shortcuts',
              'displays: Settings > Displays', 'window rules: advanced editing disabled until version-specific validation']}
    for section in SECTIONS:
        enabled = supported(backend, section)
        result['editable'][section] = enabled
        if not enabled: continue
        try:
            path, before = require_loaded(backend, section)
            result['sections'][section] = {'path': str(path), 'values': metadata_from_block(before, backend, section) or defaults(section, backend),
                                           'managed': block_span(before.decode('utf-8'), backend, section) is not None}
        except (OSError, ValueError, UnicodeError) as error:
            result['sections'][section] = {'path': str(path_for(backend, section)), 'values': defaults(section, backend),
                                           'managed': False, 'error': str(error)}
    return result


def preview(backend, section, values):
    target, before = require_loaded(backend, section)
    data = validate(backend, section, values)
    after = replace_block(before, backend, section, data)
    difference = ''.join(difflib.unified_diff(before.decode('utf-8').splitlines(True), after.decode('utf-8').splitlines(True),
                     fromfile=str(target) + ' (current)', tofile=str(target) + ' (preview)'))
    return {'ok': True, 'backend': backend, 'section': section, 'path': str(target), 'token': fingerprint(backend, section, before, data),
            'changed': after != before, 'diff': difference[-16000:], 'note': 'Preview only. No files written. Autostart runs NEXT login.'}


def atomic(path, content):
    if path.is_symlink() or path.parent.is_symlink():
        raise ValueError('Unsafe symlink during atomic save')
    fd, temporary = tempfile.mkstemp(prefix='.rusticq-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, path.stat().st_mode & 0o777 if path.exists() else 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.lexists(temporary): os.unlink(temporary)


def run(argv):
    result = subprocess.run(argv, capture_output=True, text=True, timeout=12)
    if result.returncode != 0:
        raise ValueError(' '.join(argv[:2]) + ' failed: ' + (result.stderr or result.stdout).strip()[:600])
    return result.stdout.strip()


def live_validate(backend, path):
    if backend == 'hyprland':
        if not shutil.which('hyprctl'):
            raise ValueError('hyprctl not found: live validation unavailable')
        run(['hyprctl', 'reload'])
        errors = run(['hyprctl', 'configerrors'])
        if errors and errors.strip().lower() not in ('ok', 'no errors', '[]'):
            raise ValueError('Hyprland reports config errors: ' + errors[:600])
    else:
        run(['niri', 'validate', '--config', str(path)])


def make_backup(backend, section, path, before):
    history = STATE / 'history'
    if STATE.is_symlink() or history.is_symlink():
        raise ValueError('Unsafe symlink in snapshot path')
    history.mkdir(parents=True, exist_ok=True, mode=0o700)
    history.chmod(0o700)
    folder = Path(tempfile.mkdtemp(prefix='snapshot-', dir=history))
    folder.chmod(0o700)
    (folder / 'previous.bin').write_bytes(before)
    (folder / 'previous.bin').chmod(0o600)
    info = {'backend': backend, 'section': section, 'path': str(path), 'previous_sha256': digest(before), 'after_sha256': '',
            'created': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'state': 'pending'}
    (folder / 'manifest.json').write_text(json.dumps(info, indent=2) + '\n')
    (folder / 'manifest.json').chmod(0o600)
    return folder, info


def update_manifest(folder, info):
    atomic(folder / 'manifest.json', (json.dumps(info, indent=2) + '\n').encode())


def apply(backend, section, values, token):
    if backend != compositor():
        raise ValueError('Active compositor changed since preview; refusing apply')
    target, before = require_loaded(backend, section)
    data = validate(backend, section, values)
    if fingerprint(backend, section, before, data) != token:
        raise ValueError('Preview expired: file or editor values changed. Preview again.')
    after = replace_block(before, backend, section, data)
    if before == after: return {'ok': True, 'changed': False, 'message': 'No changes to apply.'}
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    if STATE.is_symlink(): raise ValueError('Unsafe snapshot directory')
    lock = STATE / 'editor.lock'
    if lock.is_symlink(): raise ValueError('Unsafe editor lock')
    with lock.open('a+b') as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        if check_path(target) != before:
            raise ValueError('Source changed concurrently: preview again')
        # Must have a working validator and a clean baseline before editing.
        if backend == 'niri': live_validate(backend, target)
        else:
            if not shutil.which('hyprctl'):
                raise ValueError('hyprctl missing; cannot safely apply')
            errors = run(['hyprctl', 'configerrors'])
            if errors and errors.strip().lower() not in ('ok', 'no errors', '[]'):
                raise ValueError('Existing Hyprland config errors must be resolved before editing: ' + errors[:600])
        folder, info = make_backup(backend, section, target, before)
        try:
            atomic(target, after)
            live_validate(backend, target)
        except Exception as error:
            atomic(target, before)
            info['state'] = 'rolled_back'
            update_manifest(folder, info)
            try: live_validate(backend, target)
            except Exception as recovery_error:
                raise ValueError('Apply failed; old file restored but compositor validation failed: ' + str(recovery_error)) from error
            raise ValueError('Apply failed; original file restored and revalidated: ' + str(error)) from error
        info.update(state='applied', after_sha256=digest(after))
        update_manifest(folder, info)
        return {'ok': True, 'changed': True, 'message': 'Applied and validated. Autostart takes effect at next login.',
                'backup': str(folder), 'path': str(target), 'files_changed': [str(target)]}


def history_list():
    parent = STATE / 'history'
    if not parent.is_dir() or parent.is_symlink(): return []
    result = []
    for item in sorted(parent.glob('snapshot-*'), reverse=True):
        if item.is_symlink() or not item.is_dir(): continue
        try:
            info = json.loads((item / 'manifest.json').read_text())
            if info.get('state') == 'applied': result.append({'snapshot': item.name, **info})
        except (OSError, ValueError): continue
    return result[:50]


def rollback(snapshot):
    if not re.fullmatch(r'snapshot-[A-Za-z0-9_-]{6,80}', snapshot):
        raise ValueError('Invalid rollback snapshot ID')
    folder = STATE / 'history' / snapshot
    if folder.is_symlink() or not folder.is_dir(): raise ValueError('Snapshot not found')
    info = json.loads((folder / 'manifest.json').read_text())
    if info.get('state') != 'applied' or info.get('backend') != compositor():
        raise ValueError('Snapshot not active for this compositor')
    target = path_for(info['backend'], info['section'])
    if str(target) != info.get('path'): raise ValueError('Snapshot target mismatch')
    current = check_path(target)
    if digest(current) != info.get('after_sha256'):
        raise ValueError('File changed since snapshot; refusing to overwrite newer edits')
    previous = (folder / 'previous.bin').read_bytes()
    if digest(previous) != info.get('previous_sha256'): raise ValueError('Backup checksum invalid')
    atomic(target, previous)
    try: live_validate(info['backend'], target)
    except Exception as error:
        atomic(target, current)
        live_validate(info['backend'], target)
        raise ValueError('Rollback config invalid; newer file restored: ' + str(error)) from error
    info['state'] = 'restored'
    update_manifest(folder, info)
    return {'ok': True, 'message': 'Previous settings restored and validated.', 'path': str(target)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('status', 'preview', 'apply', 'history', 'rollback'))
    parser.add_argument('--section', choices=SECTIONS)
    parser.add_argument('--values', default='{}')
    parser.add_argument('--token', default='')
    parser.add_argument('--snapshot', default='')
    args = parser.parse_args()
    try:
        backend = compositor()
        if args.action == 'status': result = summary(backend)
        elif args.action == 'history': result = {'ok': True, 'snapshots': history_list()}
        elif args.action == 'rollback': result = rollback(args.snapshot)
        else:
            if not args.section: raise ValueError('Select a compositor settings section')
            if len(args.values) > 12000: raise ValueError('Editor payload exceeds size limit')
            values = json.loads(args.values)
            result = preview(backend, args.section, values) if args.action == 'preview' else apply(backend, args.section, values, args.token)
    except (ValueError, OSError, UnicodeError, subprocess.TimeoutExpired, json.JSONDecodeError) as error:
        result = {'ok': False, 'message': str(error)}
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get('ok') else 1


if __name__ == '__main__': sys.exit(main())
