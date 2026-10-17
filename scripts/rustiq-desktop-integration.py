#!/usr/bin/env python3
"""Reversible, user-only Hyprland/Omarchy desktop integration for RusticQ.

No filesystem writes happen for status or preview. Mutations require explicit
confirmation from the UI and a matching CLI token. Only known Omarchy Quattro
configuration signatures are edited; unexpected formats fail closed.
"""
import argparse
import hashlib
import json
import os
import re
import shlex
import shutil
import stat
import subprocess
import sys
from pathlib import Path

SENTINEL = 'RUSTICQ MANAGED RC4'
START = '-- BEGIN ' + SENTINEL
END = '-- END ' + SENTINEL
ACTION_CATALOG = [
    {"key": 'settings', "name": 'Settings', "category": 'Core'},
    {"key": 'launcher', "name": 'App Launcher', "category": 'Core'},
    {"key": 'quick', "name": 'Quick Control', "category": 'Core'},
    {"key": 'ai', "name": 'AI Workspace', "category": 'Core'},
    {"key": 'monitor', "name": 'System Monitor', "category": 'Core'},
    {"key": 'settings-appearance', "name": 'Appearance', "category": 'Settings pages'},
    {"key": 'settings-bar', "name": 'Bar layout', "category": 'Settings pages'},
    {"key": 'settings-modules', "name": 'Modules and indicators', "category": 'Settings pages'},
    {"key": 'settings-widgets', "name": 'Desktop widgets', "category": 'Settings pages'},
    {"key": 'settings-dock', "name": 'Dock', "category": 'Settings pages'},
    {"key": 'settings-launcher', "name": 'Launcher settings', "category": 'Settings pages'},
    {"key": 'settings-display', "name": 'Display settings', "category": 'Settings pages'},
    {"key": 'settings-os', "name": 'OS information', "category": 'Settings pages'},
    {"key": 'settings-hardware', "name": 'Hardware', "category": 'Settings pages'},
    {"key": 'settings-apps', "name": 'Installed apps', "category": 'Settings pages'},
    {"key": 'settings-storage', "name": 'Storage', "category": 'Settings pages'},
    {"key": 'settings-updates', "name": 'Arch updater', "category": 'Settings pages'},
    {"key": 'settings-shortcuts', "name": 'Keyboard shortcuts', "category": 'Settings pages'},
    {"key": 'settings-integration', "name": 'Permanent integration', "category": 'Settings pages'},
    {"key": 'settings-ai', "name": 'AI providers', "category": 'Settings pages'},
    {"key": 'settings-about', "name": 'About', "category": 'Settings pages'},
    {"key": 'popup-wifi', "name": 'Wi-Fi', "category": 'Bar popups'},
    {"key": 'popup-ethernet', "name": 'Ethernet', "category": 'Bar popups'},
    {"key": 'popup-bluetooth', "name": 'Bluetooth', "category": 'Bar popups'},
    {"key": 'popup-battery', "name": 'Battery', "category": 'Bar popups'},
    {"key": 'popup-audio', "name": 'Volume / audio', "category": 'Bar popups'},
    {"key": 'popup-weather', "name": 'Weather', "category": 'Bar popups'},
    {"key": 'popup-time', "name": 'Clock', "category": 'Bar popups'},
    {"key": 'popup-date', "name": 'Calendar', "category": 'Bar popups'},
    {"key": 'popup-task', "name": 'Task dashboard', "category": 'Bar popups'},
    {"key": 'menu-file', "name": 'File menu', "category": 'Bar menus'},
    {"key": 'menu-edit', "name": 'Edit menu', "category": 'Bar menus'},
    {"key": 'menu-view', "name": 'View menu', "category": 'Bar menus'},
    {"key": 'menu-share', "name": 'Share menu', "category": 'Bar menus'},
    {"key": 'menu-shell', "name": 'Shell menu', "category": 'Bar menus'},
    {"key": 'menu-tools', "name": 'Tools menu', "category": 'Bar menus'},
    {"key": 'mode-awake', "name": 'Keep awake', "category": 'Quick modes'},
    {"key": 'mode-silent', "name": 'Silent mode', "category": 'Quick modes'},
    {"key": 'mode-gaming', "name": 'Performance mode', "category": 'Quick modes'},
    {"key": 'mode-night', "name": 'Night light', "category": 'Quick modes'},
    {"key": 'mode-mic', "name": 'Mute microphone', "category": 'Quick modes'},
    {"key": 'workspace-1', "name": 'Workspace 1', "category": 'Workspaces'},
    {"key": 'workspace-2', "name": 'Workspace 2', "category": 'Workspaces'},
    {"key": 'workspace-3', "name": 'Workspace 3', "category": 'Workspaces'},
    {"key": 'workspace-4', "name": 'Workspace 4', "category": 'Workspaces'},
    {"key": 'workspace-5', "name": 'Workspace 5', "category": 'Workspaces'},
    {"key": 'workspace-6', "name": 'Workspace 6', "category": 'Workspaces'},
    {"key": 'workspace-7', "name": 'Workspace 7', "category": 'Workspaces'},
    {"key": 'workspace-8', "name": 'Workspace 8', "category": 'Workspaces'},
    {"key": 'workspace-9', "name": 'Workspace 9', "category": 'Workspaces'},
    {"key": 'workspace-10', "name": 'Workspace 10', "category": 'Workspaces'},
    {"key": 'dock-files', "name": 'Open Files', "category": 'Dock'},
    {"key": 'dock-browser', "name": 'Open Browser', "category": 'Dock'},
    {"key": 'item-file-home', "name": 'Home folder', "category": 'File menu'},
    {"key": 'item-file-downloads', "name": 'Downloads', "category": 'File menu'},
    {"key": 'item-file-config', "name": 'RusticQ config folder', "category": 'File menu'},
    {"key": 'item-shell-terminal', "name": 'Open terminal', "category": 'Shell menu'},
    {"key": 'item-shell-monitor', "name": 'System monitor', "category": 'Shell menu'},
    {"key": 'item-tools-settings', "name": 'Bar settings', "category": 'Tools menu'},
    {"key": 'item-tools-region', "name": 'Screenshot region', "category": 'Tools menu'},
    {"key": 'item-share-full', "name": 'Screenshot screen', "category": 'Share menu'},
    {"key": 'item-share-region', "name": 'Screenshot region', "category": 'Share menu'},
    {"key": 'item-share-start-screen', "name": 'Start screen recording', "category": 'Share menu'},
    {"key": 'item-share-start-region', "name": 'Record region', "category": 'Share menu'},
    {"key": 'item-share-start-audio', "name": 'Record with audio', "category": 'Share menu'},
    {"key": 'item-share-stop', "name": 'Stop screen recording', "category": 'Share menu'},
    {"key": 'item-share-portal-check', "name": 'Screen sharing portal', "category": 'Share menu'},
    {"key": 'item-share-record-folder', "name": 'Open recordings', "category": 'Share menu'},
    {"key": 'item-share-folder', "name": 'Open screenshots', "category": 'Share menu'},
    {"key": 'item-view-compact', "name": 'Compact bar mode', "category": 'View menu'},
    {"key": 'item-view-clean-compact', "name": 'Clean Compact bar', "category": 'View menu'},
    {"key": 'item-view-separated', "name": 'Separated bar mode', "category": 'View menu'},
    {"key": 'item-view-professional', "name": 'Professional bar mode', "category": 'View menu'},
    {"key": 'item-view-simple', "name": 'Simple bar mode', "category": 'View menu'},
]
# The top-bar registry uses stable action keys: existing saved shortcuts remain valid.
# `bar_key` corresponds to SettingsStore.barIconKeys; the menu/workspace/QuickModes
# buttons intentionally have multiple actions that can be assigned independently.
BAR_ACTIONS = {
    "rusticq": ["settings"],
    "arch": ["ai"],
    "launcher": ["launcher"],
    "menu": ["bar-menu", "menu-file", "menu-edit", "menu-view", "menu-share", "menu-shell", "menu-tools"]
            + [entry["key"] for entry in ACTION_CATALOG if entry["key"].startswith("item-")],
    "workspaces": [f"workspace-{n}" for n in range(1, 11)],
    "weather": ["popup-weather"],
    "time": ["popup-time"],
    "date": ["popup-date"],
    "bluetooth": ["popup-bluetooth"],
    "wifi": ["bar-network", "popup-wifi", "popup-ethernet"],
    "battery": ["popup-battery"],
    "audio": ["popup-audio"],
    "task": ["popup-task"],
    "quickModes": ["bar-quick-modes", "mode-awake", "mode-silent", "mode-gaming", "mode-night", "mode-mic"],
    "quickControl": ["quick"],
    "mic": ["mode-mic"],
}
# The download/upload rate counters are informational, not buttons. Assigning
# them a fake click would mislead users; System Monitor is available separately.
ACTION_CATALOG.extend([
    {"key": "bar-menu", "name": "Open first enabled bar menu", "category": "Top bar"},
    {"key": "bar-network", "name": "Network indicator (Wi-Fi / Ethernet auto)", "category": "Top bar"},
    {"key": "bar-quick-modes", "name": "Reveal Quick Modes buttons", "category": "Top bar"},
])
for bar_key, keys in BAR_ACTIONS.items():
    for action in ACTION_CATALOG:
        if action["key"] in keys:
            action.setdefault("bar_keys", []).append(bar_key)

ACTIONS = {entry["key"]: entry["name"] for entry in ACTION_CATALOG}

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
CONFIG = Path(os.environ.get('XDG_CONFIG_HOME') or HOME / '.config')
STATE = Path(os.environ.get('XDG_STATE_HOME') or HOME / '.local/state') / 'rusticq' / 'integration'
DATA = Path(os.environ.get('XDG_DATA_HOME') or HOME / '.local/share') / 'rusticq' / 'shell'
HYPR = CONFIG / 'hypr'
BINDINGS = HYPR / 'bindings.lua'
MAIN = HYPR / 'hyprland.lua'
DEFAULT_AUTOSTART = Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy') / 'default/hypr/autostart.lua'
META = STATE / 'manifest.json'
SHORTCUTS = STATE / 'shortcuts.json'
SHORTCUT_BACKUPS = STATE / 'shortcut-line-backups.json'
REMAPS = STATE / 'remaps.json'
OMARCHY_BACKUP_META = STATE / 'backup/omarchy-snapshot.json'
SHIM = STATE / 'autostart.lua'
STARTER = STATE / 'start-rusticq.sh'


def digest(value):
    return hashlib.sha256(value.encode('utf-8')).hexdigest()


def check_file(path):
    if path.is_symlink():
        raise ValueError(f'Refusing symlinked configuration: {path}')
    if path.exists() and not path.is_file():
        raise ValueError(f'Expected a regular file: {path}')
    if path.exists() and path.stat().st_size > 500_000:
        raise ValueError(f'Unusually large config; refusing to edit: {path}')


def read_file(path, required=False):
    check_file(path)
    if required and not path.is_file():
        raise ValueError(f'Missing required Omarchy Lua config: {path}')
    return path.read_text(encoding='utf-8') if path.exists() else ''


def save_atomic(path, contents, mode=None):
    check_file(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    tmp = path.with_name('.' + path.name + '.rusticq-' + str(os.getpid()))
    try:
        with tmp.open('w', encoding='utf-8', newline='') as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        if mode is None and path.exists():
            mode = stat.S_IMODE(path.stat().st_mode)
        tmp.chmod(mode if mode is not None else 0o600)
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()


def managed_block(payload):
    return START + '\n' + payload.rstrip() + '\n' + END + '\n'


def append_block(text, payload):
    if START in text or END in text:
        raise ValueError('RusticQ managed block already exists; revert first')
    return text.rstrip('\n') + '\n\n' + managed_block(payload)


def remove_block(text):
    if text.count(START) != 1 or text.count(END) != 1:
        raise ValueError('Missing or modified RusticQ markers. Restore manually using backup.')
    pat = r'(?m)^' + re.escape(START) + r'\n.*?^' + re.escape(END) + r'\n?'
    return re.sub(pat, '', text, count=1, flags=re.S | re.M).rstrip('\n') + '\n'


def validate_key(key):
    parts = [p.strip().upper() for p in key.split('+')]
    modifiers = {'SUPER', 'CTRL', 'ALT', 'SHIFT'}
    named = {'SPACE', 'RETURN', 'ENTER', 'ESCAPE', 'TAB', 'PRINT', 'BACKSPACE'}
    if len(parts) < 2 or len(parts) > 5 or len(set(parts[:-1])) != len(parts[:-1]):
        raise ValueError('Use a shortcut such as SUPER + SHIFT + R')
    if any(p not in modifiers for p in parts[:-1]) or not parts[0] or not parts[-1]:
        raise ValueError('Allowed modifiers: SUPER, CTRL, ALT, SHIFT')
    terminal = parts[-1]
    if not (re.fullmatch(r'[A-Z0-9]', terminal) or terminal in named or re.fullmatch(r'F(?:[1-9]|1[0-2])', terminal)):
        raise ValueError('Unsupported key: use A–Z, 0–9, F1–F12, SPACE, ENTER, ESCAPE, TAB, PRINT')
    if terminal in modifiers or len(set(parts)) != len(parts):
        raise ValueError('A modifier cannot be used as the final key')
    if terminal in ('ESCAPE', 'BACKSPACE') and parts == ['SUPER', terminal]:
        raise ValueError('Reserved recovery shortcut. Choose a different combination.')
    return ' + '.join(parts[:-1] + [terminal])


def check_require(contents):
    needle = 'require("default.hypr.omarchy")'
    if contents.count(needle) != 1:
        raise ValueError('Unsupported Hyprland Lua setup; expected one require("default.hypr.omarchy").')
    return needle


def backup(paths):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    folder = STATE / 'backup'
    folder.mkdir(mode=0o700, exist_ok=True)
    originals = {}
    for label, path in paths.items():
        check_file(path)
        content = read_file(path)
        originals[label] = {'path': str(path), 'existed': path.exists(), 'sha256': digest(content), 'mode': stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600}
        orig = folder / f'{label}.original'
        if not orig.exists():
            save_atomic(orig, content)
    return originals


def load_meta():
    return json.loads(META.read_text()) if META.is_file() else {}


def run_hypr_reload():
    if not shutil.which('hyprctl') or not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
        return 'Saved. Changes will apply after Hyprland starts/reloads.'
    run = subprocess.run(['hyprctl', 'reload'], capture_output=True, text=True, timeout=8)
    if run.returncode:
        raise ValueError('hyprctl reload failed: ' + (run.stderr or run.stdout).strip()[:200])
    errors = subprocess.run(['hyprctl', 'configerrors'], capture_output=True, text=True, timeout=8)
    if errors.returncode != 0 or (errors.stdout.strip() and errors.stdout.strip().lower() not in ('ok', 'no errors')):
        raise ValueError('Hyprland reports configuration errors: ' + (errors.stdout + errors.stderr).strip()[:350])
    return 'Hyprland reloaded; configuration errors checked.'


def omarchy_root():
    return Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy')


def is_omarchy():
    # Arch Linux itself does not normally identify as Omarchy in os-release.
    # Check its installed Lua package plus the user's active Hyprland wiring.
    root = omarchy_root() / 'default/hypr'
    return (root.is_dir() and (root / 'autostart.lua').is_file()
            and 'require("default.hypr.omarchy")' in read_file(MAIN))


def backup_omarchy():
    """Take an immutable local snapshot. Does not change session startup."""
    if not is_omarchy():
        raise ValueError('Omarchy Quattro Lua session not detected; no automatic backup created.')
    if META.exists() and not OMARCHY_BACKUP_META.exists():
        raise ValueError('Permanent mode already active, but its original backup is missing. Refusing to snapshot modified configs.')
    if OMARCHY_BACKUP_META.exists():
        info = json.loads(OMARCHY_BACKUP_META.read_text(encoding='utf-8'))
        return {'ok': True, 'created': False, 'backup_dir': str(OMARCHY_BACKUP_META.parent),
                'message': 'Existing automatic Omarchy backup preserved.', 'snapshot': info}
    root = omarchy_root() / 'default/hypr'
    files = {}
    size = 0
    for f in sorted(root.rglob('*')):
        if f.is_symlink():
            raise ValueError(f'Omarchy default has a symlink; refusing ambiguous backup: {f}')
        if not f.is_file():
            continue
        relative = f.relative_to(root)
        if len(relative.parts) > 8:
            raise ValueError('Unexpected Omarchy default directory depth; backup cancelled.')
        size += f.stat().st_size
        if size > 24_000_000:
            raise ValueError('Omarchy defaults exceed 24 MB; backup cancelled.')
        files[str(relative)] = f
    folder = OMARCHY_BACKUP_META.parent
    snapshot_dir = folder / 'omarchy-default-hypr'
    if snapshot_dir.exists() or OMARCHY_BACKUP_META.is_symlink():
        raise ValueError('Existing partial backup found; inspect it before retrying.')
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    snapshot_dir.mkdir(mode=0o700)
    try:
        for name, source in files.items():
            dest = snapshot_dir / name
            dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            shutil.copy2(source, dest, follow_symlinks=False)
        originals = backup({'hyprland': MAIN, 'bindings': BINDINGS,
                            'omarchy_autostart': DEFAULT_AUTOSTART,
                            'omarchy_shell': CONFIG / 'omarchy/shell.json'})
        info = {'type': 'omarchy-quattro-hypr-snapshot', 'source': str(root),
                'files': {name: digest(read_file(path)) for name, path in files.items()},
                'user_files': originals}
        save_atomic(OMARCHY_BACKUP_META, json.dumps(info, indent=2) + '\n')
    except Exception:
        if snapshot_dir.is_dir():
            shutil.rmtree(snapshot_dir)
        raise
    return {'ok': True, 'created': True, 'backup_dir': str(folder),
            'message': 'Omarchy defaults and user Hyprland configs backed up automatically.', 'snapshot': info}


def preview():
    main = read_file(MAIN)
    org = read_file(DEFAULT_AUTOSTART)
    return {
        'supported': 'require("default.hypr.omarchy")' in main,
        'source_present': ROOT.joinpath('shell.qml').is_file(),
        'omarchy_detected': is_omarchy(),
        'backup_ready': OMARCHY_BACKUP_META.is_file(),
        'hyprland_lua': str(MAIN),
        'bindings_lua': str(BINDINGS),
        'omarchy_autostart': str(DEFAULT_AUTOSTART),
        'backup_directory': str(STATE / 'backup'),
        'installed_shell': str(DATA),
        'launcher_intercept_supported': org.count('hl.exec_cmd("omarchy-launch-shell")') == 1,
        'notes': 'No changes yet. Activation is reversible and applies to the next login.',
    }


def actions_catalogue():
    return {'ok': True, 'actions': ACTION_CATALOG, 'count': len(ACTION_CATALOG)}


def load_shortcuts():
    if not SHORTCUTS.is_file():
        return {}
    shortcuts = json.loads(SHORTCUTS.read_text(encoding='utf-8'))
    if not isinstance(shortcuts, dict) or any(a not in ACTIONS or not isinstance(k, str) or validate_key(k) != k for a, k in shortcuts.items()):
        raise ValueError('Managed shortcut records are invalid. Restore from backup.')
    return shortcuts


def catalogue():
    """Read-only, best-effort inventory of Omarchy Lua bindings and user overrides."""
    sources = [
        ('user', BINDINGS),
        ('omarchy', Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy') / 'default/hypr/bindings.lua'),
    ]
    base = Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy') / 'default/hypr'
    if base.is_dir():
        sources += [('omarchy', item) for item in sorted(base.rglob('*.lua')) if item.name != 'bindings.lua' and len(item.relative_to(base).parts) <= 4]
    found = []
    # Lua functions can be dynamic; inventory extracts the first two string arguments.
    regex = re.compile(r"""(?m)\bo\.(bind|rebind)\s*\(\s*(["'])(.*?)\2\s*,\s*(["'])(.*?)\4""")
    for origin, file in sources:
        try:
            source = read_file(file)
        except (ValueError, OSError, UnicodeError):
            continue
        if origin == 'user' and START in source:
            source = source.split(START, 1)[0]
        for match in regex.finditer(source):
            combo, name = match.group(3), match.group(5)
            line_number = source.count('\n', 0, match.start()) + 1
            original_line = source.splitlines()[line_number-1]
            found.append({'key': combo, 'label': name, 'origin': origin, 'file': str(file), 'line': line_number, 'method': match.group(1), 'source_hash': digest(original_line)})
    # Include editable remaps with their original line identities.
    for remap in load_remaps().values():
        found.append({'key': remap['to'], 'label': remap['label'], 'origin': 'rusticq-remap', 'file': remap['file'], 'line': remap['line'], 'remap_id': remap['id'], 'original_key': remap['from']})
    # Managed settings are shown as a distinct source.
    for action, combo in load_shortcuts().items():
        found.append({'key': combo, 'label': 'RusticQ ' + ACTIONS[action], 'origin': 'rusticq', 'file': str(BINDINGS), 'action': action})
    return {'ok': True, 'bindings': found, 'count': len(found), 'message': 'Parsed Lua files read-only; dynamic bindings may not appear.'}


def shortcut_sources():
    root = Path(os.environ.get('OMARCHY_PATH') or '/usr/share/omarchy') / 'default/hypr'
    sources = [('user', BINDINGS)]
    if root.is_dir():
        sources += [('omarchy', p) for p in sorted(root.rglob('*.lua')) if len(p.relative_to(root).parts) <= 4]
    return sources


def matching_shortcut_lines(key):
    """Read-only source locations, preserved for targeted recovery/audit."""
    normalized = key.replace(' ', '').upper()
    records = []
    for origin, path in shortcut_sources():
        try:
            contents = read_file(path)
        except (ValueError, OSError, UnicodeError):
            continue
        if origin == 'user' and START in contents:
            contents = contents.split(START, 1)[0]
        for index, line in enumerate(contents.splitlines(), 1):
            hit = re.search(r"\bo\.(?:bind|rebind)\s*\(\s*(['\"])(.*?)\1", line)
            if hit and hit.group(2).replace(' ', '').upper() == normalized:
                records.append({'origin': origin, 'file': str(path), 'line': index, 'original_line': line, 'sha256': digest(line)})
    return records


def load_shortcut_backups():
    if not SHORTCUT_BACKUPS.exists():
        return {}
    data = json.loads(SHORTCUT_BACKUPS.read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise ValueError('Shortcut line backup is invalid')
    return data


# Only plain one-line, three-string Lua bindings are automatically remappable.
# Dynamic functions, added flags, or Lua expressions remain view-only.
SIMPLE_BIND = re.compile(r"""^\s*o\.bind\(\s*([\"'])(.*?)\1\s*,\s*([\"'])(.*?)\3\s*,\s*([\"'])(.*?)\5\s*\)\s*(?:--.*)?$""")


def load_remaps():
    if not REMAPS.exists():
        return {}
    result = json.loads(REMAPS.read_text(encoding='utf-8'))
    if not isinstance(result, dict) or any(not isinstance(v, dict) for v in result.values()):
        raise ValueError('Invalid remap registry. Inspect backup before editing.')
    return result


def source_binding(file, line, expected_hash):
    """Resolve only a line from an installed Omarchy or user Lua source."""
    candidates = [p.resolve() for _, p in shortcut_sources() if p.is_file() and not p.is_symlink()]
    target = Path(file)
    if target.is_symlink() or not target.is_file() or target.resolve() not in candidates:
        raise ValueError('Shortcut source is not a recognized local Lua file.')
    content = read_file(target)
    original = content.splitlines()
    if line < 1 or line > len(original):
        raise ValueError('Shortcut source line no longer exists; refresh the list.')
    raw = original[line-1]
    if digest(raw) != expected_hash:
        raise ValueError('Original Lua source line has changed; refresh before applying.')
    parsed = SIMPLE_BIND.fullmatch(raw)
    if not parsed:
        raise ValueError('Only static one-line o.bind(key, label, command) is editable safely. This binding is view-only.')
    old, label, cmd = parsed.group(2), parsed.group(4), parsed.group(6)
    old = validate_key(old)
    ident = digest(str(target.resolve()) + '\0' + str(line) + '\0' + raw)[:24]
    return {'id': ident, 'file': str(target), 'line': line, 'source_hash': expected_hash,
            'original_line': raw, 'from': old, 'label': label, 'command': cmd}


def write_shortcuts(mapping, previous_content, remaps=None):
    if remaps is None:
        remaps = load_remaps()
    base_content = remove_block(previous_content) if START in previous_content else previous_content
    target_shell = DATA if META.is_file() else ROOT
    unbinds, binds = [], []
    def unbind(key):
        if key not in unbinds:
            unbinds.append(key)
    for r in remaps.values():
        unbind(r['from'])
        unbind(r['to'])
        binds.append('o.bind(' + ', '.join(json.dumps(v) for v in (r['to'], r['label'], r['command'])) + ')')
    for act in ACTIONS:
        if act not in mapping:
            continue
        combo = mapping[act]
        command = 'quickshell ipc -p ' + shlex.quote(str(target_shell)) + ' call rusticq dispatch ' + shlex.quote(act)
        unbind(combo)
        binds.append('o.bind(' + json.dumps(combo) + ', ' + json.dumps('RusticQ ' + ACTIONS[act]) + ', ' + json.dumps(command) + ')')
    lines = ['hl.unbind(' + json.dumps(k) + ')' for k in unbinds] + binds
    if lines:
        return append_block(base_content, '\n'.join(lines))
    # Preserve the exact original ending/blank lines when the user hasn't
    # edited the underlying bindings between first install and final revert.
    original_backup = STATE / 'shortcut-original.txt'
    if original_backup.is_file():
        pristine = original_backup.read_text(encoding='utf-8')
        if pristine.rstrip('\n') == base_content.rstrip('\n'):
            return pristine
    return base_content


def remap_binding(file, line, source_hash, key):
    item = source_binding(file, line, source_hash)
    dest = validate_key(key)
    if dest == item['from']:
        raise ValueError('Choose a different combination or use Revert to restore original.')
    map_ = load_shortcuts()
    others = load_remaps()
    if dest in map_.values() or any(r['to'] == dest for ident, r in others.items() if ident != item['id']):
        raise ValueError('Combination already managed by RusticQ. Revert the other override first.')
    if item['from'] in map_.values() or any(r['from'] == item['from'] for ident, r in others.items() if ident != item['id']):
        raise ValueError('Source combination already overridden by RusticQ.')
    updated_map = dict(others)
    item['to'] = dest
    updated_map[item['id']] = item
    content = read_file(BINDINGS)
    if (map_ or others) and START not in content:
        raise ValueError('Managed block missing; refusing to overwrite user configuration.')
    if START in content and not (map_ or others):
        raise ValueError('Orphaned managed block; recover the previous metadata first.')
    updated = write_shortcuts(map_, content, updated_map)
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Literal lines kept for auditing, but the source Lua is never modified.
    original_backup = STATE / 'shortcut-original.txt'
    if not original_backup.exists():
        save_atomic(original_backup, remove_block(content) if START in content else content)
    old_backups = load_shortcut_backups()
    old_backups[item['id']] = [dict(item)]
    save_atomic(BINDINGS, updated)
    try:
        msg = run_hypr_reload()
    except Exception:
        save_atomic(BINDINGS, content)
        raise
    save_atomic(REMAPS, json.dumps(updated_map, indent=2) + '\n')
    save_atomic(SHORTCUT_BACKUPS, json.dumps(old_backups, indent=2) + '\n')
    return {'ok': True, 'message': item['from'] + ' → ' + dest + '. Original line preserved. ' + msg, 'remap_id': item['id']}


def restore_remap(ident):
    current_map = load_remaps()
    if ident not in current_map:
        raise ValueError('Selected remap does not exist; refresh the list.')
    updated_map = dict(current_map)
    removed = updated_map.pop(ident)
    current = read_file(BINDINGS)
    if START not in current:
        raise ValueError('Managed block missing. Cannot safely revert.')
    updated = write_shortcuts(load_shortcuts(), current, updated_map)
    save_atomic(BINDINGS, updated)
    try:
        msg = run_hypr_reload()
    except Exception:
        save_atomic(BINDINGS, current)
        raise
    if updated_map:
        save_atomic(REMAPS, json.dumps(updated_map, indent=2) + '\n')
    elif REMAPS.exists():
        REMAPS.unlink()
    old_backups = load_shortcut_backups()
    old_backups.pop(ident, None)
    if old_backups:
        save_atomic(SHORTCUT_BACKUPS, json.dumps(old_backups, indent=2) + '\n')
    elif SHORTCUT_BACKUPS.exists():
        SHORTCUT_BACKUPS.unlink()
    return {'ok': True, 'message': 'Restored original ' + removed['from'] + ' binding at ' + removed['file'] + ':' + str(removed['line']) + '. ' + msg}


def apply_keybinding(combo, action):
    if action not in ACTIONS:
        raise ValueError('Unsupported shortcut action')
    key = validate_key(combo)
    old_map = load_shortcuts()
    if any(r['to'] == key or r['from'] == key for r in load_remaps().values()):
        raise ValueError('Combination is already managed by a remapped Omarchy binding.')
    if any(k == key and a != action for a, k in old_map.items()):
        raise ValueError('Key already used by another RusticQ action. Restore that action first.')
    content = read_file(BINDINGS)
    if old_map and START not in content:
        raise ValueError('Managed record exists without Lua markers. Refusing to overwrite.')
    if START in content and not (old_map or load_remaps()):
        raise ValueError('Orphaned managed Lua block; refusing to replace it.')
    previous_backups = load_shortcut_backups()
    new_backups = dict(previous_backups)
    # Omarchy defaults are NEVER edited. Save the literal original lines and positions.
    if key not in new_backups:
        new_backups[key] = matching_shortcut_lines(key)
    mapping = dict(old_map)
    previous_key = mapping.get(action)
    mapping[action] = key
    if previous_key and previous_key != key and previous_key not in mapping.values():
        new_backups.pop(previous_key, None)
    updated = write_shortcuts(mapping, content)
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    original_backup = STATE / 'shortcut-original.txt'
    if not original_backup.exists():
        save_atomic(original_backup, remove_block(content) if START in content else content)
    save_atomic(BINDINGS, updated)
    try:
        reload_message = run_hypr_reload()
    except Exception:
        save_atomic(BINDINGS, content)
        raise
    save_atomic(SHORTCUTS, json.dumps(mapping, indent=2) + '\n')
    save_atomic(SHORTCUT_BACKUPS, json.dumps(new_backups, indent=2) + '\n')
    return {'ok': True, 'message': f'{key} → {ACTIONS[action]}. Original lines backed up. ' + reload_message, 'shortcut': key, 'action': action}


def restore_shortcut(action=None):
    mapping = load_shortcuts()
    if action is not None and action not in ACTIONS:
        raise ValueError('Unknown shortcut action')
    if not mapping:
        if START in read_file(BINDINGS) and not load_remaps():
            raise ValueError('Orphaned managed block found. Restore manually from backup.')
        return {'ok': True, 'message': 'No managed RusticQ action shortcuts to restore.'}
    if action and action not in mapping:
        return {'ok': True, 'message': 'This action has no override.'}
    current = read_file(BINDINGS)
    if START not in current:
        raise ValueError('Cannot revert: managed block missing. Backup kept.')
    changed = dict(mapping)
    if action:
        removed_key = changed.pop(action)
    else:
        changed.clear()
        removed_key = None
    updated = write_shortcuts(changed, current)
    save_atomic(BINDINGS, updated)
    try:
        result = run_hypr_reload()
    except Exception:
        save_atomic(BINDINGS, current)
        raise
    if changed:
        save_atomic(SHORTCUTS, json.dumps(changed, indent=2) + '\n')
    elif SHORTCUTS.exists():
        SHORTCUTS.unlink()
    backups = load_shortcut_backups()
    active_keys = set(changed.values()) | set(load_remaps().keys())
    backups = {key: value for key, value in backups.items() if key in active_keys}
    if backups:
        save_atomic(SHORTCUT_BACKUPS, json.dumps(backups, indent=2) + '\n')
    elif SHORTCUT_BACKUPS.exists():
        SHORTCUT_BACKUPS.unlink()
    # Original default bindings are revealed again after hl.unbind is removed.
    # No user/default Lua source lines were ever rewritten.
    return {'ok': True, 'message': ('Restored ' + (removed_key or 'all shortcuts') + '. ' + result)}


def safe_copy_shell():
    if not (ROOT / 'shell.qml').is_file():
        raise ValueError('Missing RusticQ shell.qml source')
    # A copy under XDG_DATA_HOME survives changing the development directory.
    if DATA.exists():
        raise ValueError('RusticQ installation already exists; revert first to avoid overwriting user data')
    DATA.parent.mkdir(parents=True, exist_ok=True)
    ignore = shutil.ignore_patterns('__pycache__', '*.pyc', '.git', '.pytest_cache', '.venv')
    shutil.copytree(ROOT, DATA, ignore=ignore, symlinks=False)
    if not (DATA / 'shell.qml').is_file():
        raise ValueError('Unable to copy installed RusticQ shell')


def enable_permanent(token):
    if token != 'ENABLE RUSTICQ':
        raise ValueError('Type ENABLE RUSTICQ to authorize changing session startup.')
    if META.exists():
        raise ValueError('RusticQ is already permanently installed. Revert before reinstalling.')
    current_main = read_file(MAIN, required=True)
    check_require(current_main)
    if not is_omarchy():
        raise ValueError('Omarchy Quattro session not detected. Permanent integration disabled.')
    original_autostart = read_file(DEFAULT_AUTOSTART, required=True)
    needle = 'hl.exec_cmd("omarchy-launch-shell")'
    if original_autostart.count(needle) != 1:
        raise ValueError('Omarchy autostart differs from the supported Quattro version. No changes made.')
    if START in current_main:
        raise ValueError('A RusticQ integration block already exists. Revert first.')
    if SHIM.exists() or STARTER.exists() or DATA.exists():
        raise ValueError('Previous installation files exist. Move or restore them manually before installing.')
    backup_result = backup_omarchy()
    originals = backup_result['snapshot']['user_files']
    patched_autostart = original_autostart.replace(needle, 'hl.exec_cmd(' + json.dumps(shlex.quote(str(STARTER))) + ')', 1)
    preload = 'package.preload["default.hypr.autostart"] = function()\n  dofile(' + json.dumps(str(SHIM)) + ')\n  return true\nend'
    new_main = current_main.replace('require("default.hypr.omarchy")', managed_block(preload) + 'require("default.hypr.omarchy")', 1)
    # Existing RusticQ bindings must be repointed at the stable installed copy.
    original_bindings = read_file(BINDINGS)
    installed_bindings = original_bindings
    if START in original_bindings:
        old_cmd = 'quickshell ipc -p ' + shlex.quote(str(ROOT)) + ' call rusticq '
        new_cmd = 'quickshell ipc -p ' + shlex.quote(str(DATA)) + ' call rusticq '
        # json.dumps quotes plain no-space paths unchanged; fail instead of leaving
        # a broken shortcut when an unexpected representation is present.
        if old_cmd not in original_bindings:
            raise ValueError('Managed shortcut format is unknown; restore shortcut before installing.')
        installed_bindings = original_bindings.replace(old_cmd, new_cmd)
    metadata = {'version': 1, 'backup': originals, 'main_applied_hash': digest(new_main), 'omarchy_autostart_source_hash': digest(original_autostart), 'installed_shell': str(DATA)}
    try:
        safe_copy_shell()
        save_atomic(SHIM, patched_autostart)
        save_atomic(STARTER, '#!/bin/sh\nexec ' + shlex.quote(shutil.which('quickshell') or '/usr/bin/quickshell') + ' -n -p ' + shlex.quote(str(DATA)) + '\n', 0o700)
        save_atomic(MAIN, new_main)
        if installed_bindings != original_bindings:
            save_atomic(BINDINGS, installed_bindings)
        save_atomic(META, json.dumps(metadata, indent=2) + '\n')
        # Deliberately no Hyprland reload here. Replacement takes effect at next login.
    except Exception:
        # Undo only this transaction; no shell processes are ever killed.
        save_atomic(MAIN, current_main)
        if read_file(BINDINGS) != original_bindings:
            save_atomic(BINDINGS, original_bindings)
        if META.exists(): META.unlink()
        for path in (STARTER, SHIM):
            if path.exists(): path.unlink()
        if DATA.exists(): shutil.rmtree(DATA)
        raise
    return {'ok': True, 'message': 'RusticQ installed for next login. Omarchy shell and user configs are backed up; current session unchanged.', 'backup_dir': str(STATE / 'backup')}


def revert_permanent(token):
    if token != 'RESTORE OMARCHY':
        raise ValueError('Type RESTORE OMARCHY to authorize reverting startup.')
    meta = load_meta()
    if not meta:
        return {'ok': True, 'message': 'Permanent RusticQ integration is not installed.'}
    existing = read_file(MAIN, required=True)
    if digest(existing) != meta.get('main_applied_hash'):
        # Allow external edits outside the generated block if managed content is still exact.
        try:
            original = remove_block(existing)
        except ValueError:
            raise ValueError('Hyprland config changed since install. Manual merge needed; backup was preserved.')
    else:
        original = (STATE / 'backup/hyprland.original').read_text(encoding='utf-8')
    # Keep shortcut overrides independent from permanent shell integration.
    # Rebuild managed commands against the active development copy, not DATA.
    bindings = read_file(BINDINGS)
    save_atomic(MAIN, original)
    META.unlink()
    new_bindings = write_shortcuts(load_shortcuts(), bindings, load_remaps()) if START in bindings else bindings
    if new_bindings != bindings:
        save_atomic(BINDINGS, new_bindings)
    for path in (SHIM, STARTER):
        if path.exists(): path.unlink()
    # Park rather than delete the installed shell. This preserves preferences
    # changed while running from the installed copy and allows reinstalling.
    parked = None
    if DATA.is_dir():
        for n in range(1, 100):
            candidate = DATA.parent / ('shell-previous' if n == 1 else 'shell-previous-' + str(n))
            if not candidate.exists():
                DATA.rename(candidate)
                parked = candidate
                break
        if parked is None:
            raise ValueError('Startup restored; installed shell needs manual archival before reinstall.')
    msg = 'Omarchy startup restored for next login. Shortcut overrides kept independent; snapshots retained.'
    if parked is not None:
        msg += ' Previous RusticQ install parked at ' + str(parked)
    return {'ok': True, 'message': msg}


def status():
    manifest = load_meta()
    bindings = read_file(BINDINGS)
    return {'ok': True, 'permanent': bool(manifest), 'shortcut_managed': START in bindings, 'shortcuts': load_shortcuts(), 'shortcut_backups': load_shortcut_backups(), 'remaps': load_remaps(), 'backup_dir': str(STATE / 'backup'), 'omarchy_backup_ready': OMARCHY_BACKUP_META.is_file(),
            'installed_shell': str(DATA), 'omarchy_source': str(DEFAULT_AUTOSTART), 'compatibility': preview()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['status', 'preview', 'bindings', 'actions', 'shortcut', 'shortcut-revert', 'remap', 'remap-revert', 'backup-omarchy', 'enable', 'revert'])
    parser.add_argument('--key', default='SUPER + SHIFT + R')
    parser.add_argument('--action', default='settings', choices=list(ACTIONS))
    parser.add_argument('--all', action='store_true', help='Revert all RusticQ action shortcuts')
    parser.add_argument('--file', default='')
    parser.add_argument('--line', type=int, default=0)
    parser.add_argument('--hash', dest='source_hash', default='')
    parser.add_argument('--id', dest='remap_id', default='')
    parser.add_argument('--confirm', default='')
    args = parser.parse_args()
    try:
        result = {
            'status': status,
            'preview': preview,
            'bindings': catalogue,
            'actions': actions_catalogue,
            'shortcut': lambda: apply_keybinding(args.key, args.action),
            'shortcut-revert': lambda: restore_shortcut(None if args.all else args.action),
            'remap': lambda: remap_binding(args.file, args.line, args.source_hash, args.key),
            'remap-revert': lambda: restore_remap(args.remap_id),
            'backup-omarchy': backup_omarchy,
            'enable': lambda: enable_permanent(args.confirm),
            'revert': lambda: revert_permanent(args.confirm)
        }[args.operation]()
        print(json.dumps(result))
    except Exception as error:
        print(json.dumps({'ok': False, 'message': str(error)}))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
