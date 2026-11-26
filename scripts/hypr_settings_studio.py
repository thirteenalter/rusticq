"""Hyprland studio extension of rusticq-compositor-config (not a second writer).

All persistent operations use the gateway's atomic writer and editor lock.
The original file is changed only to source one owned fragment, after a diff.
"""
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import difflib
import fcntl
import glob
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import time

from hypr_settings_schema import OPTIONS, BY_ID, CATEGORIES, PRESETS

TAG = 'RUSTICQ HYPRLAND SETTINGS'
META = 'RUSTICQ-STUDIO-DATA '
COLLECTIONS = {
    'workspaces': [('workspace', 'Workspace', 'string', '1'), ('monitor', 'Monitor', 'string', ''),
                   ('layout', 'Layout override', 'choice', ['', 'dwindle', 'master']), ('persistent', 'Persistent', 'bool', True),
                   ('default', 'Default on monitor', 'bool', False)],
    'window-rules': [('class', 'Window class (regex)', 'string', ''), ('title', 'Title (regex)', 'string', ''),
                     ('initial_class', 'Initial class', 'string', ''), ('initial_title', 'Initial title', 'string', ''),
                     ('mode', 'Mode', 'choice', ['unchanged', 'float', 'tile', 'fullscreen']),
                     ('workspace', 'Workspace', 'string', ''), ('monitor', 'Monitor', 'string', ''),
                     ('move', 'Position (x y)', 'string', ''), ('size', 'Size (width height)', 'string', ''),
                     ('opacity', 'Opacity (0.1–1)', 'string', ''), ('rounding', 'Rounding', 'string', '')],
    'layer-rules': [('namespace', 'Layer namespace (regex)', 'string', ''), ('blur', 'Blur', 'bool', True),
                    ('ignore_alpha', 'Ignore alpha (0–1)', 'string', '0.02'), ('no_anim', 'Disable animation', 'bool', False),
                    ('animation', 'Animation', 'string', '')],
    'animations': [('leaf', 'Animation target', 'choice', ['windows', 'windowsIn', 'windowsOut', 'workspaces', 'layers', 'fade', 'border']),
                    ('enabled', 'Enabled', 'bool', True), ('speed', 'Speed', 'string', '4'),
                    ('style', 'Style', 'choice', ['', 'slide', 'popin', 'fade']),
                    ('x1', 'Curve X1', 'string', '0.23'), ('y1', 'Curve Y1', 'string', '1'),
                    ('x2', 'Curve X2', 'string', '0.32'), ('y2', 'Curve Y2', 'string', '1')],
    'gestures': [('fingers', 'Fingers', 'choice', ['3', '4', '5']),
                  ('direction', 'Direction', 'choice', ['horizontal', 'vertical', 'left', 'right', 'up', 'down']),
                  ('action', 'Action', 'choice', ['workspace', 'close', 'float', 'fullscreen']),
                  ('mods', 'Modifiers', 'string', ''), ('scale', 'Sensitivity', 'string', '1')],
    'autostart': [('command', 'Startup command', 'string', ''), ('once', 'Run once per session', 'bool', True)],
    'environment': [('name', 'Variable name', 'string', ''), ('value', 'Value (non-secret only)', 'string', '')],
    'devices': [('name', 'Device name', 'string', ''), ('kb_layout', 'Keyboard layout', 'string', ''),
                ('kb_variant', 'Keyboard variant', 'string', ''), ('sensitivity', 'Sensitivity (−1–1)', 'string', ''),
                ('natural_scroll', 'Natural scrolling', 'bool', False)],
}


def packed(core, value):
    return core.canonical(value).encode("utf8")


def ctl(core, *args, optional=False):
    try:
        proc = subprocess.run(['hyprctl', *args], capture_output=True, text=True, timeout=5)
        if proc.returncode:
            raise ValueError(proc.stderr.strip() or proc.stdout.strip() or 'hyprctl failed')
        return proc.stdout.strip()
    except (OSError, ValueError, subprocess.TimeoutExpired):
        if optional:
            return ''
        raise ValueError('Hyprland could not be contacted. Run in an active Hyprland session.')


def query(core, name, fallback):
    try:
        return json.loads(ctl(core, '-j', *name.split()))
    except (ValueError, json.JSONDecodeError):
        return fallback


def safe_bytes(core, path, missing=False):
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Symlinked paths are read-only: ' + str(path))
    if not path.exists() and missing:
        return None
    data = core.check_path(path)
    if path.stat().st_uid != os.getuid():
        raise ValueError('Configuration is not owned by this user')
    return data


def detect(core):
    version = query(core, 'version', {})
    if not isinstance(version,dict): version={}
    text = str(version.get('version') or version.get('tag') or '')
    match = re.search(r'(\d+)\.(\d+)\.(\d+)', text)
    ver = tuple(map(int, match.groups())) if match else (0, 0, 0)
    root = None
    # The process command line is authoritative for custom --config locations.
    signature = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
    instances=query(core,'instances',[])
    for instance in instances if isinstance(instances,list) else []:
        if not isinstance(instance,dict): continue
        if instance.get('instance') != signature:
            continue
        try:
            args = Path('/proc', str(int(instance['pid'])), 'cmdline').read_bytes().decode().split('\0')
            for index, arg in enumerate(args):
                if arg in ('-c', '--config'):
                    root = Path(args[index + 1]).expanduser()
                elif arg.startswith('--config='):
                    root = Path(arg.split('=', 1)[1]).expanduser()
            if root is not None and not root.is_absolute():
                root = Path('/proc',str(int(instance['pid'])),'cwd').resolve() / root
        except (OSError, ValueError, IndexError):
            pass
    if root is None:
        candidates = [core.CONFIG / 'hypr/hyprland.lua', core.CONFIG / 'hypr/hyprland.conf']
        if ver < (0, 55, 0):
            candidates.reverse()
        root = next((p for p in candidates if p.is_file()), candidates[0])
    root = root.absolute()
    fmt = 'lua' if root.suffix == '.lua' else 'hyprlang' if root.suffix == '.conf' else 'unknown'
    managed = root.parent / ('rusticq-studio.lua' if fmt == 'lua' else 'rusticq-studio.conf')
    reason = ''
    try:
        safe_bytes(core, root)
        safe_bytes(core, managed, missing=True)
        if not shutil.which('hyprctl'):
            raise ValueError('hyprctl is missing. Install the Hyprland CLI through your package manager.')
        if core.compositor() != 'hyprland' or not version:
            raise ValueError('An active Hyprland session is required; other compositors remain unchanged.')
        if fmt == 'unknown' or not ((fmt == 'lua' and (0, 55, 0) <= ver < (0, 58, 0)) or
                                    (fmt == 'hyprlang' and (0, 40, 0) <= ver < (0, 55, 0))):
            raise ValueError('This configuration format/version has not been audited for writing.')
    except (ValueError, OSError) as exc:
        reason = str(exc)
    return dict(version=text or 'Unavailable', build=version, versionTuple=ver, path=str(root),
                format=fmt, managedPath=str(managed), editable=not reason, reason=reason,
                active=core.compositor()=='hyprland' and bool(version),
                omarchy=(core.HOME / '.local/share/omarchy').exists() or Path('/usr/share/omarchy').exists())


def included_files(core, root):
    """Static includes only. Never execute user Lua to discover paths."""
    found, pending = {}, [root]
    while pending and len(found) < 80:
        path = pending.pop()
        if str(path) in found or not path.is_file() or path.stat().st_size > 2_000_000:
            continue
        data = path.read_bytes()
        found[str(path)] = core.digest(data)
        source = data.decode('utf8', errors='replace')
        patterns = re.findall(r'(?m)^\s*source\s*=\s*([^\n#]+)', source)
        patterns += re.findall(r'(?:dofile|require)\s*\(\s*[\'"]([^\'"]+)[\'"]\s*\)', source)
        for name in patterns:
            if '$' in name and not name.startswith('$HOME/'):
                continue
            name = name.strip().replace('$HOME', str(core.HOME))
            if not name.endswith(('.conf', '.lua')) and '/' not in name:
                name = name.replace('.', '/') + '.lua'
                pattern = str(core.CONFIG / name)
            else:
                target = Path(name).expanduser()
                pattern = str(target if target.is_absolute() else path.parent / target)
            pending.extend(Path(p) for p in glob.glob(pattern))
    return found


def managed_data(core, info):
    path = Path(info['managedPath'])
    if not path.exists():
        return {'options': {}, 'records': {}}
    text = safe_bytes(core, path).decode('utf8')
    matches = re.findall(r'^.*' + META + r'([A-Za-z0-9+/=]+)$', text, re.M)
    if len(matches)!=1:
        raise ValueError('An unrecognized file occupies the studio fragment path; refusing to overwrite it.')
    data=json.loads(base64.b64decode(matches[0]))
    if not isinstance(data,dict) or set(data)!= {'options','records'} or not all(isinstance(data[k],dict) for k in data):
        raise ValueError('Managed configuration metadata is invalid')
    return data


def probe_option(core, spec, fmt):
    result = dict(spec, supported=False, effective=None, reason='Not exposed by this Hyprland version')
    names = [spec['id'].replace(':', '.'), spec['id']] if fmt == 'lua' else [spec['id']]
    for name in names:
        try:
            raw = json.loads(ctl(core, '-j', 'getoption', name))
            if not isinstance(raw, dict) or raw.get('error'):
                continue
            fields = {'bool': 'int', 'int': 'int', 'float': 'float', 'string': 'str'}
            value = raw.get('bool') if spec['type'] == 'bool' and 'bool' in raw else raw.get(fields[spec['type']])
            if value is None:
                value = raw.get('value')
            if value is None and spec['type'] in ('int','float'):
                css = raw.get('css') or raw.get('custom')
                if isinstance(css,str) and re.fullmatch(r'-?\d+(?:\.\d+)?(?:\s+-?\d+(?:\.\d+)?){0,3}',css.strip()):
                    gaps = [float(v) for v in css.split()]
                    if len(set(gaps)) == 1: value = int(gaps[0]) if spec['type']=='int' else gaps[0]
            if value is None and spec['type'] == 'string':
                color = raw.get('gradient') or raw.get('custom')
                if isinstance(color,str) and re.fullmatch(r'[0-9a-fA-F]{8}(?:\s+\d+(?:\.\d+)?deg)?',color): color='0x'+color.split()[0]
                if isinstance(color,str) and re.fullmatch(r'(?:rgba\([0-9a-fA-F]{8}\)|rgb\([0-9a-fA-F]{6}\)|0x[0-9a-fA-F]{8})',color): value=color
            if value is None:
                # Complex colors and four-sided gaps are still supported, but
                # cannot be flattened into a fabricated scalar effective value.
                if raw.get('option') or any(k in raw for k in ('custom','data','css','gradient')):
                    return dict(result, supported=True, reason='Complex current value; enter a scalar override')
                continue
            if spec['type'] == 'bool':
                value = bool(int(value))
            return dict(result, supported=True, effective=value, reason='')
        except (ValueError, TypeError, json.JSONDecodeError):
            continue
    return result


def runtime_schema(core):
    """Use native descriptions for version-specific defaults and numeric limits.

    Unknown defaults stay unknown. A reset can then remove our override rather
    than presenting a guessed factory value as an authoritative default.
    """
    rows=query(core,'descriptions',[])
    if not isinstance(rows,list): rows=[]
    lookup={}
    for row in rows:
        if not isinstance(row,dict): continue
        name=row.get('name') or row.get('value')
        if isinstance(name,str): lookup[name]=row
    result={}
    for base in OPTIONS:
        spec=dict(base,defaultKnown=False)
        row=lookup.get(base['id']) or lookup.get(base['id'].replace(':','.'))
        if row:
            detail=row.get('data') if isinstance(row.get('data'),dict) else row
            if isinstance(row.get('description'),str): spec['description']=row['description'][:600]
            for field,target in [('min','minimum'),('max','maximum')]:
                bound=detail.get(field)
                if base['type'] in ('int','float') and isinstance(bound,(int,float)) and not isinstance(bound,bool) and math.isfinite(bound):
                    spec[target]=bound
            if 'default' in detail:
                value=detail['default'];known=True
                try:
                    if base['type']=='bool':
                        if not isinstance(value,(bool,int)) or value not in (0,1): raise ValueError('Not a bool')
                        value=bool(value)
                    elif base['type'] in ('int','float'):
                        if isinstance(value,str) and ' ' in value.strip():
                            values=value.split()
                            if len(set(values))!=1: raise ValueError('Complex default')
                            value=values[0]
                        value=number(value,spec['minimum'],spec['maximum'])
                        if base['type']=='int':
                            if value!=int(value): raise ValueError('Not an integer')
                            value=int(value)
                    else:
                        value=plain(value)
                        if 'color' in base['label'].lower():
                            if re.fullmatch(r'[0-9a-fA-F]{8}(?:\s+\d+(?:\.\d+)?deg)?',value): value='0x'+value.split()[0]
                            if not re.fullmatch(r'(?:rgba\([0-9a-fA-F]{8}\)|rgb\([0-9a-fA-F]{6}\)|0x[0-9a-fA-F]{8})',value): raise ValueError('Complex color')
                        if base['choices'] and value not in base['choices']: raise ValueError('Unsupported default')
                except (ValueError,TypeError): known=False
                if known: spec.update(default=value,defaultKnown=True)
        result[base['id']]=spec
    return result


def status(core):
    info = detect(core)
    schema=runtime_schema(core)
    with ThreadPoolExecutor(max_workers=6) as pool:
        options = list(pool.map(lambda spec: probe_option(core, spec, info['format']), schema.values())) if info['build'] else [
            dict(spec, supported=False, effective=None, reason=info['reason']) for spec in schema.values()]
    try:
        data = managed_data(core, info)
    except (ValueError, OSError) as exc:
        data = {'options': {}, 'records': {}}
        info.update(editable=False, reason=str(exc))
    files = included_files(core, Path(info['path']))
    schemas = {key: [dict(key=f[0], label=f[1], type=f[2], default=f[3]) for f in fields]
               for key, fields in COLLECTIONS.items()}
    lua = info['format'] == 'lua'
    support = {key: info['editable'] and (lua or key in ('workspaces', 'animations', 'autostart', 'environment', 'devices'))
               for key in COLLECTIONS}
    errors = ctl(core, 'configerrors', optional=True)
    custom = custom_presets(core)
    presets=dict(PRESETS,**custom)
    defaults={o['id']:o['default'] for o in options if o.get('defaultKnown') and o['supported'] and o['page'] in ('appearance','effects','animations')}
    if defaults: presets['Default Hyprland']=defaults
    return dict(ok=True, info=info, options=options, data=data, categories=[dict(key=k, label=l, group=g, icon=i) for k, l, g, i in CATEGORIES],
                collections=schemas, collectionSupport=support, presets=presets, files=files,
                revision=core.digest(packed(core, files)), configErrors=errors,
                monitors=query(core, 'monitors', []), workspace=query(core, 'activeworkspace', {}),
                clients=query(core, 'clients', []), layers=query(core, 'layers', {}),
                devices=query(core, 'devices', {}), plugins=query(core, 'plugin list', []))


def plain(value, limit=400):
    if not isinstance(value, str) or len(value) > limit or any(ord(c) < 32 for c in value):
        raise ValueError('Expected a single line of text (maximum %s characters)' % limit)
    return value


def number(value, low, high):
    if isinstance(value, bool):
        raise ValueError('Expected a number')
    try:
        value = float(value)
    except (TypeError, ValueError):
        raise ValueError('Expected a finite number')
    if not math.isfinite(value) or not low <= value <= high:
        raise ValueError('Value must be between %s and %s' % (low, high))
    return value


def validate_options(core, info, values):
    if not isinstance(values, dict) or len(values) > len(OPTIONS):
        raise ValueError('Invalid option collection')
    result = {}
    schema=runtime_schema(core)
    for key, value in values.items():
        spec = schema.get(key)
        if not spec or not probe_option(core, spec, info['format'])['supported']:
            raise ValueError('Unsupported option: ' + key)
        kind = spec['type']
        if kind == 'bool':
            if not isinstance(value, bool):
                raise ValueError(key + ' requires a boolean')
        elif kind in ('int', 'float'):
            value = number(value, spec['minimum'], spec['maximum'])
            if kind == 'int':
                if value != int(value):
                    raise ValueError(key + ' requires a whole number')
                value = int(value)
        else:
            value = plain(value)
            if spec['choices'] and value not in spec['choices']:
                raise ValueError('Unsupported choice for ' + key)
            if 'color' in spec['label'].lower() and not re.fullmatch(r'(?:rgba\([0-9a-fA-F]{8}\)|rgb\([0-9a-fA-F]{6}\)|0x[0-9a-fA-F]{8})', value):
                raise ValueError('Use rgb(RRGGBB) or rgba(RRGGBBAA) for colors')
            if info['format'] == 'hyprlang' and re.search(r'[#{}$;]', value):
                raise ValueError('Unsafe character in legacy configuration value')
        result[key] = value
    return result


def validate_records(info, records):
    if not isinstance(records, dict) or set(records) - set(COLLECTIONS):
        raise ValueError('Unknown record collection')
    result = {}
    for kind, rows in records.items():
        if info['format'] != 'lua' and kind not in ('workspaces', 'animations', 'autostart', 'environment', 'devices'):
            raise ValueError('Rule schema is not audited for this version: ' + kind)
        if not isinstance(rows, list) or len(rows) > 64:
            raise ValueError('Maximum 64 entries per collection')
        keys = {f[0]: f for f in COLLECTIONS[kind]}
        normalized, seen = [], set()
        for row in rows:
            if not isinstance(row, dict) or set(row) - set(keys) - {'enabled'}:
                raise ValueError('Unknown fields in ' + kind)
            item = {}
            for key, field in keys.items():
                value = row.get(key, field[3][0] if field[2] == 'choice' else field[3])
                if field[2] == 'bool':
                    if not isinstance(value, bool):
                        raise ValueError(key + ' requires a boolean')
                else:
                    value = plain(value)
                    if field[2] == 'choice' and value not in field[3]:
                        raise ValueError('Invalid choice: ' + key)
                    if info['format'] == 'hyprlang' and re.search(r'[#{}$;\n\r]', value):
                        raise ValueError('Unsafe legacy record text')
                item[key] = value
            if not isinstance(row.get('enabled', True), bool):
                raise ValueError('enabled requires a boolean')
            item['enabled'] = row.get('enabled', True)
            if kind == 'window-rules':
                if not any(item[k] for k in ('class', 'title', 'initial_class', 'initial_title')):
                    raise ValueError('A window rule requires at least one match')
                for key in ('move', 'size'):
                    if item[key] and not re.fullmatch(r'-?\d{1,5} -?\d{1,5}', item[key]):
                        raise ValueError(key + ' requires two integer coordinates')
                if item['opacity']: number(item['opacity'], 0.1, 1)
                if item['rounding']: number(item['rounding'], 0, 60)
            elif kind == 'layer-rules':
                if not item['namespace']: raise ValueError('Layer namespace is required')
                number(item['ignore_alpha'], 0, 1)
            elif kind == 'animations':
                number(item['speed'], 0.1, 30)
                for key in ('x1', 'x2'): number(item[key], 0, 1)
                for key in ('y1', 'y2'): number(item[key], -2, 3)
            elif kind == 'gestures':
                number(item['scale'], 0.1, 10)
            elif kind == 'autostart' and not item['command']:
                raise ValueError('Startup command is required')
            elif kind == 'environment':
                if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]{0,100}', item['name']):
                    raise ValueError('Invalid environment variable name')
                if re.search(r'(TOKEN|PASSWORD|SECRET|PRIVATE|API_KEY|CREDENTIAL)', item['name'], re.I):
                    raise ValueError('Store secrets in a credential manager, not compositor configuration')
            elif kind == 'devices':
                if not re.fullmatch(r'[a-zA-Z0-9_.:-]{1,150}', item['name']):
                    raise ValueError('Select a device name from hyprctl devices')
                if item['sensitivity']: number(item['sensitivity'], -1, 1)
            elif kind == 'workspaces':
                if not re.fullmatch(r'(?:[1-9]\d{0,3}|name:[\w -]{1,60}|special:[\w-]{1,60})', item['workspace']):
                    raise ValueError('Use a workspace number, name:label, or special:label')
            identity = json.dumps({k: v for k, v in item.items() if k != 'enabled'}, sort_keys=True)
            if identity in seen: raise ValueError('Duplicate entry in ' + kind)
            seen.add(identity)
            normalized.append(item)
        result[kind] = normalized
    return result


def lua(core, value):
    if isinstance(value, bool): return 'true' if value else 'false'
    if isinstance(value, (int, float)): return str(value)
    if isinstance(value, dict): return '{ ' + ', '.join('[' + core.lua_string(k) + '] = ' + lua(core, v) for k, v in value.items()) + ' }'
    return core.lua_string(value)


def generate(core, info, data):
    is_lua = info['format'] == 'lua'
    comment = '-- ' if is_lua else '# '
    text = comment + META + base64.b64encode(packed(core, data)).decode() + '\n'
    options = data['options']
    if is_lua:
        tree = {}
        for key, value in options.items():
            parts = re.split(r'[:.]', key)
            branch = tree
            for part in parts[:-1]: branch = branch.setdefault(part, {})
            branch[parts[-1]] = value
        text += 'hl.config(' + lua(core, tree) + ')\n'
    else:
        text += ''.join(k + ' = ' + ('true' if v is True else 'false' if v is False else str(v)) + '\n' for k, v in options.items())
    for kind, rows in data['records'].items():
        for index, row in enumerate(rows):
            if kind != 'animations' and not row.get('enabled', True): continue
            item = {k: v for k, v in row.items() if k != 'enabled' and v != ''}
            if kind == 'window-rules':
                match = {k: item.pop(k) for k in ('class', 'title', 'initial_class', 'initial_title') if k in item}
                mode = item.pop('mode', 'unchanged')
                if mode != 'unchanged': item[mode] = True
                if 'opacity' in item: item['opacity'] = float(item['opacity'])
                if 'rounding' in item: item['rounding'] = int(item['rounding'])
                item.update(name='rusticq-window-' + str(index), match=match)
                text += 'hl.window_rule(' + lua(core, item) + ')\n'
            elif kind == 'layer-rules':
                namespace = item.pop('namespace')
                item['ignore_alpha'] = float(item['ignore_alpha'])
                item.update(name='rusticq-layer-' + str(index), match={'namespace': namespace})
                text += 'hl.layer_rule(' + lua(core, item) + ')\n'
            elif kind == 'workspaces':
                if is_lua: text += 'hl.workspace_rule(' + lua(core, item) + ')\n'
                else:
                    workspace = item.pop('workspace')
                    text += 'workspace = ' + workspace + ', ' + ', '.join(k + ':' + str(v).lower() for k, v in item.items()) + '\n'
            elif kind == 'animations':
                name = 'rusticqCurve' + str(index)
                x1, y1, x2, y2 = [float(row[k]) for k in ('x1', 'y1', 'x2', 'y2')]
                if is_lua:
                    text += 'hl.curve(' + core.lua_string(name) + ', { type = "bezier", points = {{%s, %s}, {%s, %s}} })\n' % (x1, y1, x2, y2)
                    text += 'hl.animation(' + lua(core, {k: v for k, v in dict(leaf=row['leaf'], enabled=row['enabled'], speed=float(row['speed']), bezier=name, style=row['style']).items() if v != ''}) + ')\n'
                else:
                    text += 'bezier = %s, %s, %s, %s, %s\n' % (name, x1, y1, x2, y2)
                    text += 'animation = %s, %s, %s, %s%s\n' % (row['leaf'], int(row['enabled']), row['speed'], name, ', ' + row['style'] if row['style'] else '')
            elif kind == 'gestures':
                item['fingers'], item['scale'] = int(item['fingers']), float(item['scale'])
                text += 'hl.gesture(' + lua(core, item) + ')\n'
            elif kind == 'autostart':
                if is_lua:
                    call = 'hl.exec_cmd(' + core.lua_string(item['command']) + ')'
                    text += ('hl.on("hyprland.start", function() ' + call + ' end)' if item['once'] else call) + '\n'
                else: text += ('exec-once' if item['once'] else 'exec') + ' = ' + item['command'] + '\n'
            elif kind == 'environment':
                text += ('hl.env(' + core.lua_string(row['name']) + ', ' + core.lua_string(row['value']) + ')' if is_lua else 'env = ' + row['name'] + ',' + row['value']) + '\n'
            elif kind == 'devices':
                if 'sensitivity' in item: item['sensitivity'] = float(item['sensitivity'])
                text += ('hl.device(' + lua(core, item) + ')' if is_lua else 'device {\n' + ''.join('    ' + k + ' = ' + str(v).lower() + '\n' for k, v in item.items()) + '}') + '\n'
    return text.encode()


def main_with_source(core, info, before):
    comment = '-- ' if info['format'] == 'lua' else '# '
    start, end = comment + 'BEGIN ' + TAG, comment + 'END ' + TAG
    text = before.decode('utf8')
    if info['format'] == 'lua' and re.search(r'(?m)^return\b',text):
        raise ValueError('Entrypoint returns before an appended source could run; use an explicit non-returning entrypoint.')
    path = info['managedPath']
    command = 'dofile(' + core.lua_string(path) + ')' if info['format'] == 'lua' else 'source = ' + path
    if start in text or end in text:
        if text.count(start) != 1 or text.count(end) != 1 or text.index(end) < text.index(start):
            raise ValueError('Malformed studio source markers; repair manually before applying')
        body = text.split(start, 1)[1].split(end, 1)[0].strip()
        if body != command:
            raise ValueError('Studio source block was edited externally; refusing an ineffective write')
        return before
    if info['format'] != 'lua' and re.search(r'[\n\r#$]', path):
        raise ValueError('Legacy source path contains unsupported characters')
    return (text + '\n' + start + '\n' + command + '\n' + end + '\n').encode()


def preview(core, payload):
    info = detect(core)
    if not info['editable']: raise ValueError(info['reason'])
    root, managed = Path(info['path']), Path(info['managedPath'])
    original = safe_bytes(core, root)
    previous = safe_bytes(core, managed, missing=True)
    managed_data(core, info)  # refuse to overwrite a foreign fragment
    current_revision = core.digest(packed(core, included_files(core, root)))
    if payload.get('revision') != current_revision:
        raise ValueError('Configuration changed externally. Refresh and review your changes again.')
    data = dict(options=validate_options(core, info, payload.get('options', {})),
                records=validate_records(info, payload.get('records', {})))
    after = generate(core, info, data)
    main_after = main_with_source(core, info, original)
    token = core.digest(packed(core, dict(path=str(root), revision=current_revision, data=data,
                                          root=core.digest(original), fragment=core.digest(previous or b''))))
    diff = ''.join(difflib.unified_diff(original.decode().splitlines(True), main_after.decode().splitlines(True), fromfile=str(root), tofile=str(root)))
    diff += ''.join(difflib.unified_diff((previous or b'').decode().splitlines(True), after.decode().splitlines(True), fromfile=str(managed), tofile=str(managed)))
    # Hide the encoded metadata line in the review; the actual generated config remains visible.
    diff = '\n'.join(line for line in diff.splitlines() if META not in line)
    return dict(ok=True, token=token, diff=diff, generated=after.decode(), data=data, info=info,
                _before=[original, previous], _after=[main_after, after])


def history(core):
    folder = core.STATE / 'studio-history'
    result = []
    if folder.is_dir():
        for path in sorted(folder.glob('*/manifest.json'), reverse=True)[:40]:
            try:
                info = json.loads(path.read_text())
                result.append({k: info[k] for k in ('id', 'time', 'state', 'path')})
            except (OSError, ValueError, KeyError): pass
    return result


def check_live(core):
    errors = ctl(core, 'configerrors')
    if errors and errors not in ('[]', 'ok'):
        raise ValueError('Hyprland reports configuration errors: ' + errors[:1200])


def reload_checked(core):
    ctl(core, 'reload')
    check_live(core)


def verify_effective(core, info, options):
    for key, expected in options.items():
        actual = probe_option(core, BY_ID[key], info['format'])['effective']
        if actual is None: continue  # complex gradients/gap vectors cannot be flattened safely
        if isinstance(expected, (int, float)) and not isinstance(expected, bool):
            matches = isinstance(actual, (int,float)) and abs(actual-expected) <= 0.015
        else:
            matches = actual == expected
        if not matches: raise ValueError('Effective runtime value did not match the applied value for ' + key)


def restore_files(core, paths, blobs):
    # Restore the fragment before the main source. Missing files are deliberately removed.
    for path, blob in reversed(list(zip(paths, blobs))):
        if blob is None: path.unlink(missing_ok=True)
        else: core.atomic(path, blob)


def apply(core, payload, token):
    core.STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (core.STATE / 'editor.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        plan = preview(core, payload)
        if not token or token != plan['token']: raise ValueError('Preview expired. Review a new diff before applying.')
        check_live(core)
        paths = [Path(plan['info']['path']), Path(plan['info']['managedPath'])]
        snapshot = time.strftime('%Y%m%dT%H%M%S') + '-' + str(time.time_ns())
        folder = core.STATE / 'studio-history' / snapshot
        folder.mkdir(parents=True, mode=0o700)
        manifest = dict(id=snapshot, time=time.time(), state='prepared', path=str(paths[0]), paths=list(map(str, paths)),
                        before=[base64.b64encode(b).decode() if b is not None else None for b in plan['_before']],
                        after=[core.digest(b) for b in plan['_after']])
        core.atomic(folder / 'manifest.json', packed(core, manifest))
        try:
            # Recheck every included file under the shared lock before any write.
            if payload['revision'] != core.digest(packed(core, included_files(core, paths[0]))):
                raise ValueError('Configuration changed during validation')
            core.atomic(paths[1], plan['_after'][1])
            core.atomic(paths[0], plan['_after'][0])
            reload_checked(core)
            verify_effective(core,plan['info'],plan['data']['options'])
            manifest['state'] = 'applied'
            manifest['includes'] = included_files(core,paths[0])
            core.atomic(folder / 'manifest.json', packed(core, manifest))
        except Exception as exc:
            restore_files(core, paths, plan['_before'])
            manifest['state'] = 'rolled-back'
            core.atomic(folder / 'manifest.json', packed(core, manifest))
            try: reload_checked(core)
            except ValueError as recovery: raise ValueError('Files restored; compositor recovery failed: ' + str(recovery)) from exc
            raise ValueError('Apply failed; original files restored: ' + str(exc)) from exc
    return dict(ok=True, message='Configuration applied and validated. Backup: ' + snapshot, snapshot=snapshot)


def restore_preview(core, snapshot):
    if not re.fullmatch(r'[0-9T-]{12,80}',snapshot): raise ValueError('Invalid snapshot identifier')
    info=detect(core)
    if not info['editable']: raise ValueError(info['reason'])
    managed_data(core,info)  # a foreign file at the owned path is never removed
    manifest=json.loads((core.STATE/'studio-history'/snapshot/'manifest.json').read_text())
    if manifest.get('paths') != [info['path'],info['managedPath']]: raise ValueError('Snapshot target does not match the active configuration')
    paths=list(map(Path,manifest['paths']))
    current=[safe_bytes(core,p,missing=i>0) for i,p in enumerate(paths)]
    target=base64.b64decode(manifest['before'][1]) if manifest['before'][1] is not None else None
    if target is not None:
        if META not in target.decode('utf8'): raise ValueError('Snapshot does not contain a recognized managed fragment')
        root_after=main_with_source(core,info,current[0])
    else:
        # Remove only our own source block. New user comments and settings survive.
        main_with_source(core,info,current[0])  # validate an existing source block
        comment='-- ' if info['format']=='lua' else '# '
        pattern=r'(?ms)^'+re.escape(comment+'BEGIN '+TAG)+r'\n.*?^'+re.escape(comment+'END '+TAG)+r'\n?'
        root_after=re.sub(pattern,'',current[0].decode('utf8')).encode('utf8')
    after=[root_after,target]
    revision=included_files(core,paths[0])
    token=core.digest(packed(core,dict(snapshot=snapshot,files=revision,
                                     before=[core.digest(b) if b is not None else None for b in current],
                                     after=[core.digest(b) if b is not None else None for b in after])))
    diff=''.join(''.join(difflib.unified_diff((old or b'').decode().splitlines(True),(new or b'').decode().splitlines(True),
                                            fromfile=str(path),tofile=str(path))) for path,old,new in zip(paths,current,after))
    diff='\n'.join(line for line in diff.splitlines() if META not in line)
    return dict(ok=True,snapshot=snapshot,token=token,diff=diff,_paths=paths,_current=current,_after=after)


def rollback(core, snapshot, token=''):
    if not re.fullmatch(r'[0-9T-]{12,80}', snapshot): raise ValueError('Invalid snapshot identifier')
    core.STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (core.STATE / 'editor.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        if token:
            plan=restore_preview(core,snapshot)
            if plan['token'] != token: raise ValueError('Restore preview expired; review the new diff')
            paths,current,after=plan['_paths'],plan['_current'],plan['_after']
            # Snapshot the current managed state, so a successful restore can itself be undone.
            name=time.strftime('%Y%m%dT%H%M%S')+'-'+str(time.time_ns())
            folder=core.STATE/'studio-history'/name;folder.mkdir(parents=True,mode=0o700)
            backup=dict(id=name,time=time.time(),state='prepared',path=str(paths[0]),paths=list(map(str,paths)),
                        before=[base64.b64encode(b).decode() if b is not None else None for b in current],
                        after=[core.digest(b) if b is not None else None for b in after])
            core.atomic(folder/'manifest.json',packed(core,backup))
            try:
                restore_files(core,paths,after)
                reload_checked(core)
                backup['state']='applied';backup['includes']=included_files(core,paths[0])
                core.atomic(folder/'manifest.json',packed(core,backup))
            except Exception as exc:
                restore_files(core,paths,current)
                backup['state']='rolled-back';core.atomic(folder/'manifest.json',packed(core,backup))
                reload_checked(core)
                raise ValueError('Restore failed; current configuration recovered: '+str(exc)) from exc
            return dict(ok=True,message='Managed snapshot restored. Current user configuration was preserved.',snapshot=name)
        folder = core.STATE / 'studio-history' / snapshot
        manifest = json.loads((folder / 'manifest.json').read_text())
        info = detect(core)
        if not info['editable'] or manifest['state'] != 'applied' or manifest['paths'] != [info['path'], info['managedPath']]:
            raise ValueError('Snapshot does not match the active configuration')
        paths = list(map(Path, manifest['paths']))
        current = [safe_bytes(core, p, missing=i > 0) for i, p in enumerate(paths)]
        if [core.digest(b) if b is not None else None for b in current] != manifest['after']:
            raise ValueError('Configuration changed after this snapshot; refusing to overwrite newer edits')
        if manifest.get('includes') != included_files(core,paths[0]):
            raise ValueError('Included configuration changed after this snapshot; refresh before restoring')
        before = [base64.b64decode(b) if b is not None else None for b in manifest['before']]
        restore_files(core, paths, before)
        try:
            reload_checked(core)
            manifest['state'] = 'restored'
            core.atomic(folder / 'manifest.json', packed(core, manifest))
        except Exception:
            restore_files(core, paths, current)
            reload_checked(core)
            raise ValueError('Restore failed validation; current configuration recovered')
    return dict(ok=True, message='Snapshot restored and validated')


def snapshot(core):
    """Explicit snapshot: no compositor change and the same shared edit lock."""
    info = detect(core)
    if not info['editable']: raise ValueError(info['reason'])
    core.STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (core.STATE / 'editor.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        paths = [Path(info['path']), Path(info['managedPath'])]
        blobs = [safe_bytes(core, p, missing=i > 0) for i, p in enumerate(paths)]
        name = time.strftime('%Y%m%dT%H%M%S') + '-' + str(time.time_ns())
        folder = core.STATE / 'studio-history' / name
        folder.mkdir(parents=True, mode=0o700)
        manifest = dict(id=name, time=time.time(), state='applied', path=str(paths[0]), paths=list(map(str,paths)),
                        before=[base64.b64encode(b).decode() if b is not None else None for b in blobs],
                        after=[core.digest(b) if b is not None else None for b in blobs],includes=included_files(core,paths[0]))
        core.atomic(folder / 'manifest.json', packed(core, manifest))
    return dict(ok=True, message='Snapshot created without changing configuration.', snapshot=name)


def custom_presets(core):
    path = core.STATE / 'studio-presets.json'
    try:
        data = json.loads(safe_bytes(core,path))
        if not isinstance(data,dict): return {}
        return {name: values for name,values in data.items() if isinstance(name,str) and isinstance(values,dict)
                and all(k in BY_ID and BY_ID[k]['page'] in ('appearance','effects','animations','performance','layouts') for k in values)}
    except (ValueError,OSError,TypeError): return {}


def save_preset(core, name, payload):
    if not re.fullmatch(r'[\w -]{1,50}',name) or name in PRESETS or name=='Default Hyprland':
        raise ValueError('Choose a new preset name (1–50 letters, digits, spaces or dashes)')
    info = detect(core)
    if not info['editable']: raise ValueError(info['reason'])
    values = validate_options(core,info,payload.get('options',{}))
    values = {k:v for k,v in values.items() if BY_ID[k]['page'] in ('appearance','effects','animations','performance','layouts')}
    if not values: raise ValueError('Stage appearance, effects or layout values before saving a preset')
    core.STATE.mkdir(parents=True,exist_ok=True,mode=0o700)
    with (core.STATE / 'editor.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX | fcntl.LOCK_NB)
        data = custom_presets(core)
        if len(data) >= 30 and name not in data: raise ValueError('Maximum 30 custom presets')
        data[name] = values
        core.atomic(core.STATE / 'studio-presets.json', packed(core,data))
    return dict(ok=True,message='Preset saved. No compositor setting was changed.',presets=dict(PRESETS,**data))


def transfer(core, action, path, payload):
    target = Path(path).expanduser().absolute()
    if not target.is_absolute() or target.suffix != '.json': raise ValueError('Choose a .json settings file')
    if action == 'import':
        data = json.loads(core.check_path(target))
        if not isinstance(data,dict) or data.get('format') != 'rusticq-hypr-settings-v1': raise ValueError('Not a RusticQ studio settings export')
        info = detect(core)
        values = validate_options(core,info,data.get('options',{}))
        records = validate_records(info,data.get('records',{}))
        return dict(ok=True,data=dict(options=values,records=records),message='Imported into a local draft. Review the diff before applying.')
    info = detect(core)
    values = validate_options(core,info,payload.get('options',{}))
    records = validate_records(info,payload.get('records',{}))
    if any(p.is_symlink() for p in (target,*target.parents)): raise ValueError('Symlinked export paths are not writable')
    core.atomic(target,packed(core,dict(format='rusticq-hypr-settings-v1',options=values,records=records)))
    return dict(ok=True,message='RusticQ-managed settings exported. Unmanaged configuration was not included.')


def dispatch(core):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['studio-status', 'studio-preview', 'studio-apply', 'studio-history', 'studio-restore', 'studio-restore-preview', 'studio-read', 'studio-reload',
                                         'studio-snapshot', 'studio-preset', 'studio-import', 'studio-export'])
    parser.add_argument('--values', default='{}')
    parser.add_argument('--token', default='')
    parser.add_argument('--snapshot', default='')
    parser.add_argument('--path', default='')
    parser.add_argument('--name', default='')
    args = parser.parse_args()
    if args.action in ('studio-apply','studio-restore'):
        def cancelled(signum, frame):
            raise InterruptedError('Configuration operation was cancelled')
        signal.signal(signal.SIGTERM,cancelled)
        signal.signal(signal.SIGINT,cancelled)
    try:
        if len(args.values) > 100_000: raise ValueError('Editor payload exceeds size limit')
        payload=json.loads(args.values)
        if not isinstance(payload,dict): raise ValueError('Expected a JSON settings object')
        if args.action == 'studio-status': result = status(core)
        elif args.action == 'studio-history': result = dict(ok=True, snapshots=history(core))
        elif args.action == 'studio-restore': result = rollback(core, args.snapshot,args.token)
        elif args.action == 'studio-restore-preview': result={k:v for k,v in restore_preview(core,args.snapshot).items() if not k.startswith('_')}
        elif args.action == 'studio-snapshot': result = snapshot(core)
        elif args.action == 'studio-preset': result = save_preset(core,args.name,payload)
        elif args.action in ('studio-import','studio-export'): result = transfer(core,args.action[7:],args.path,payload)
        elif args.action == 'studio-reload':
            if core.compositor() != 'hyprland': raise ValueError('Hyprland session required')
            reload_checked(core)
            result = dict(ok=True, message='Configuration reloaded and validated')
        elif args.action == 'studio-read':
            info = detect(core)
            files = included_files(core, Path(info['path']))
            if args.path not in files and args.path != info['managedPath']:
                raise ValueError('Select a file from the active include graph')
            path = Path(args.path)
            result = dict(ok=True, path=str(path), text=core.check_path(path).decode('utf8'), readOnly=True)
        else:
            result = preview(core, payload) if args.action == 'studio-preview' else apply(core, payload, args.token)
            result = {k: v for k, v in result.items() if not k.startswith('_')}
    except BlockingIOError:
        result = dict(ok=False,message='Another RusticQ configuration operation is running. Wait for it to finish, then retry.')
    except (ValueError, OSError, UnicodeError, KeyError, TypeError, subprocess.TimeoutExpired) as exc:
        result = dict(ok=False, message=str(exc))
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result.get('ok') else 1
