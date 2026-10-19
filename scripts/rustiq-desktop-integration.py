#!/usr/bin/env python3
"""Reversible, user-only Hyprland/Omarchy desktop integration for RusticQ.

No filesystem writes happen for status or preview. Mutations require explicit
confirmation from the UI and a matching CLI token. Only known Omarchy Quattro
configuration signatures are edited; unexpected formats fail closed.
"""
import argparse
import time
import hashlib
import json
import os
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
import time
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
    {"key": 'power', "name": 'Power menu', "category": 'Core'},
    {"key": 'lock', "name": 'RusticQ lock screen', "category": 'Core'},
    {"key": 'settings-appearance', "name": 'Appearance', "category": 'Settings pages'},
    {"key": 'settings-bar', "name": 'Bar layout', "category": 'Settings pages'},
    {"key": 'bar-toggle', "name": 'Toggle desktop bar', "category": 'Bar visibility'},
    {"key": 'osd-volume-up', "name": 'Volume up (+5%)', "category": 'System OSD / hardware'},
    {"key": 'osd-volume-down', "name": 'Volume down (-5%)', "category": 'System OSD / hardware'},
    {"key": 'osd-volume-mute', "name": 'Mute / unmute speaker', "category": 'System OSD / hardware'},
    {"key": 'osd-microphone-mute', "name": 'Mute / unmute microphone', "category": 'System OSD / hardware'},
    {"key": 'osd-brightness-up', "name": 'Screen brightness up', "category": 'System OSD / hardware'},
    {"key": 'osd-brightness-down', "name": 'Screen brightness down', "category": 'System OSD / hardware'},
    {"key": 'osd-keyboard-up', "name": 'Keyboard light up', "category": 'System OSD / hardware'},
    {"key": 'osd-keyboard-down', "name": 'Keyboard light down', "category": 'System OSD / hardware'},
    {"key": 'osd-touchpad-toggle', "name": 'Enable / disable touchpad', "category": 'System OSD / hardware'},
    {"key": 'bar-show', "name": 'Show desktop bar', "category": 'Bar visibility'},
    {"key": 'bar-hide', "name": 'Hide desktop bar', "category": 'Bar visibility'},
    {"key": 'bar-hide-completely', "name": 'Show / hide bar completely', "category": 'Bar visibility'},
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
    {"key": 'item-shell-power', "name": 'Power menu', "category": 'Shell menu'},
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
    "barToggle": ["bar-toggle", "bar-show", "bar-hide", "bar-hide-completely"],
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
INSTALL_PROGRESS = STATE / 'permanent-install-progress.json'


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
    # SUPER + ESCAPE may be reassigned with explicit GUI confirmation.
    # Source lines and all historical backups remain available for recovery.
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
        orig = folder / f'{label}.original'
        if not orig.exists():
            save_atomic(orig, content)
        # An earlier shortcut override may already have captured an older
        # pre-RusticQ original. Its verified digest must describe *that* copy,
        # never the newer managed contents of the live user file.
        originals[label] = {'path': str(path), 'existed': path.exists(),
                            'sha256': digest(read_file(orig)),
                            'mode': stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600}
    return originals


def load_meta():
    return json.loads(META.read_text()) if META.is_file() else {}


def restore_bindings_after_rejected_reload(previous, error):
    """Fail closed: restore the exact old file AND reload it in the compositor.

    The previous implementation restored only the file, leaving a possibly
    invalid in-memory Hyprland configuration until the user manually reloaded.
    Backup snapshots are never touched by this recovery path.
    """
    try:
        save_atomic(BINDINGS, previous)
    except (OSError, ValueError) as restore_error:
        raise ValueError('Shortcut rejected (' + str(error) + '); automatic file restore FAILED: '
                         + str(restore_error) + '. Use saved shortcut-history backup.') from restore_error
    try:
        run_hypr_reload()
    except (OSError, ValueError, subprocess.TimeoutExpired) as recovery_error:
        raise ValueError('Shortcut rejected (' + str(error) + '); previous bindings restored to disk '
                         'but Hyprland reload/validation failed: ' + str(recovery_error)) from recovery_error
    raise ValueError('Shortcut rejected (' + str(error) + '); original bindings restored '
                     'and Hyprland reloaded. Snapshot backup preserved.') from error


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


# Immutable recovery reference: snapshots are private and NEVER auto-restored
# wholesale over unrelated user edits. Only managed MAIN/BINDINGS are reverted.
TREE_ROOT = STATE / 'backup' / 'user-config-preinstall'
TREE_META = STATE / 'backup' / 'user-config-index.json'
BACKUP_CONFIG_DIRS = ('hypr', 'omarchy', 'quickshell')

# Shortcut backup layer is independent of the existing permanent-shell backup.
# Full distribution defaults are immutable (once per machine); user dotfiles
# get a new snapshot BEFORE EACH mutating shortcut/remap operation. Nothing is
# automatically written back from snapshots: recovery must be deliberate.
SHORTCUT_ARCHIVES = STATE / 'backup' / 'shortcut-history'
FULL_DEFAULT_SNAPSHOT = STATE / 'backup' / 'omarchy-default-complete'
# Omarchy/Hyprland-relevant dotfiles; deliberately exclude unrelated app data,
# browsers, account databases, and secrets from arbitrary ~/.config folders.
SHORTCUT_CONFIG_DIRS = (
    'hypr', 'omarchy', 'quickshell', 'waybar', 'mako', 'swaync',
    'swayosd', 'walker', 'fuzzel', 'rofi', 'wofi', 'wlogout',
    'ghostty', 'kitty', 'alacritty', 'foot', 'wezterm',
    'starship', 'fastfetch', 'btop', 'nvim', 'uwsm',
)
SHORTCUT_CONFIG_FILES = ('starship.toml', 'mimeapps.list')
SHORTCUT_HOME_DOTFILES = (
    '.bashrc', '.bash_profile', '.bash_aliases', '.zshrc', '.zprofile',
    '.zshenv', '.profile', '.inputrc', '.Xresources', '.gitconfig',
)


def private_backup_directory(path):
    """Refuse symlinked backup destinations and apply restrictive permissions."""
    for item in (STATE, STATE / 'backup', SHORTCUT_ARCHIVES):
        if item.is_symlink() or (item.exists() and not item.is_dir()):
            raise ValueError('Unsafe backup directory (symlink or non-directory): ' + str(item))
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    for item in (STATE, STATE / 'backup', SHORTCUT_ARCHIVES, path):
        if item.is_dir():
            if item.is_symlink():
                raise ValueError('Unsafe symlink in backup path: ' + str(item))
            item.chmod(0o700)


def _capture_sources(stage, sources, kind, max_bytes):
    """Copy exact tree contents, never following source symlinks."""
    records, missing = {}, []
    total_bytes = 0
    for prefix, origin in sources:
        if not prefix or Path(prefix).is_absolute() or '..' in Path(prefix).parts:
            raise ValueError('Invalid backup section')
        # A symlinked top-level config tree can refer outside this scope.
        # Reject rather than falsely claiming its external target was copied.
        if origin.is_symlink():
            raise ValueError('Symlinked top-level config cannot be snapshotted completely: ' + str(origin))
        if not origin.exists():
            missing.append(prefix)
            continue
        if not origin.is_dir() and not origin.is_file():
            raise ValueError('Unsupported config entry: ' + str(origin))
        paths = [origin] + sorted(origin.rglob('*')) if origin.is_dir() else [origin]
        for item in paths:
            suffix = item.relative_to(origin) if origin.is_dir() else Path()
            rel = Path(prefix) / suffix
            if len(rel.parts) > 24:
                raise ValueError('Backup depth exceeded: ' + str(rel))
            dest = stage / rel
            if item.is_symlink():
                # Nested links are represented in the archive as links, never
                # dereferenced to arbitrary filesystem paths.
                link = str(item.readlink())
                dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                dest.symlink_to(link)
                records[rel.as_posix()] = dict(type='symlink', sha256=digest(link))
            elif item.is_dir():
                dest.mkdir(parents=True, exist_ok=True, mode=0o700)
            elif item.is_file():
                file_size = item.stat().st_size
                if file_size > 64_000_000 or total_bytes + file_size > max_bytes:
                    raise ValueError('Backup size limit exceeded (' + kind + '); shortcut unchanged')
                total_bytes += file_size
                dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                shutil.copyfile(item, dest, follow_symlinks=False)
                dest.chmod(0o600)
                records[rel.as_posix()] = dict(type='file',
                    sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),
                    original_mode=stat.S_IMODE(item.stat().st_mode))
            else:
                raise ValueError('Unsupported special config file: ' + str(item))
            if len(records) > 18000:
                raise ValueError('Backup file-count limit exceeded; shortcut unchanged')
    return dict(version=1, kind=kind, source_roots={k: str(v) for k, v in sources},
                files=records, missing=missing, count=len(records), bytes=total_bytes,
                created_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))


def verify_shortcut_archive(folder):
    """Verify immutable snapshot against SHA256 for every recorded item."""
    manifest = folder / 'manifest.json'
    if folder.is_symlink() or not folder.is_dir() or manifest.is_symlink() or not manifest.is_file():
        raise ValueError('Shortcut snapshot is missing or unsafe: ' + str(folder))
    data = json.loads(manifest.read_text(encoding='utf-8'))
    if data.get('version') != 1 or data.get('kind') not in ('omarchy-default-complete', 'user-dotfiles-before-shortcut'):
        raise ValueError('Unknown shortcut backup manifest')
    entries = data.get('files')
    if not isinstance(entries, dict) or len(entries) != data.get('count'):
        raise ValueError('Invalid shortcut backup inventory')
    for relative, record in entries.items():
        rel = Path(relative)
        if rel.is_absolute() or '..' in rel.parts or not rel.parts or rel.parts[0] not in ('default', 'config', 'home'):
            raise ValueError('Invalid shortcut backup entry: ' + relative)
        target = folder / rel
        if record.get('type') == 'file':
            if target.is_symlink() or not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != record.get('sha256'):
                raise ValueError('Shortcut snapshot checksum mismatch: ' + relative)
        elif record.get('type') == 'symlink':
            if not target.is_symlink() or digest(str(target.readlink())) != record.get('sha256'):
                raise ValueError('Shortcut snapshot symlink mismatch: ' + relative)
        else:
            raise ValueError('Invalid backup entry type')
    return dict(ok=True, path=str(folder), kind=data['kind'], files=len(entries),
                bytes=data.get('bytes', 0), created=data.get('created_utc', ''))


def _write_shortcut_archive(target, sources, kind, max_bytes):
    parent = target.parent
    private_backup_directory(parent)
    if target.exists() or target.is_symlink():
        raise ValueError('Snapshot destination already exists; refusing overwrite: ' + str(target))
    stage = Path(tempfile.mkdtemp(prefix='.pending-snapshot-', dir=parent))
    stage.chmod(0o700)
    try:
        manifest = _capture_sources(stage, sources, kind, max_bytes)
        save_atomic(stage / 'manifest.json', json.dumps(manifest, indent=2) + '\n', 0o600)
        stage.rename(target)
        return verify_shortcut_archive(target)
    except Exception:
        if stage.exists():
            shutil.rmtree(stage)
        raise


def ensure_full_default_archive():
    """One immutable backup of ALL /usr/share/omarchy/default, not just hypr/."""
    if FULL_DEFAULT_SNAPSHOT.exists() or FULL_DEFAULT_SNAPSHOT.is_symlink():
        return verify_shortcut_archive(FULL_DEFAULT_SNAPSHOT)
    origin = omarchy_root() / 'default'
    if not origin.exists():
        # Do not mistake a broken/relocated Omarchy install for ordinary Hyprland.
        # is_omarchy() requires this directory and would otherwise return False.
        main = read_file(MAIN)
        if 'default.hypr.omarchy' in main or (omarchy_root() / 'bin/omarchy').exists():
            raise ValueError('Omarchy full defaults missing at ' + str(origin) + '. Backup and shortcut change aborted. Check OMARCHY_PATH.')
        return None  # Independent non-Omarchy Hyprland can still use RusticQ.
    return _write_shortcut_archive(FULL_DEFAULT_SNAPSHOT,
            [('default', origin)], 'omarchy-default-complete', 512_000_000)


def shortcut_backup_sources():
    result = [('config/' + name, CONFIG / name) for name in SHORTCUT_CONFIG_DIRS]
    result += [('config/' + name, CONFIG / name) for name in SHORTCUT_CONFIG_FILES]
    result += [('home/' + name, HOME / name) for name in SHORTCUT_HOME_DOTFILES]
    return result


def backup_before_shortcut_change(operation):
    """Verified independent backup BEFORE a shortcut or remap changes.

    Do not call backup_omarchy(): that belongs to permanent shell integration,
    and its legacy subset/symlink limits can block the independent full archive.
    """
    if META.is_file() and not OMARCHY_BACKUP_META.is_file():
        raise ValueError('Permanent shell integration has missing recovery metadata; repair that backup before changing bindings.')
    defaults = ensure_full_default_archive()
    identifier = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()) + '-' + str(time.time_ns())
    target = SHORTCUT_ARCHIVES / identifier
    snapshot = _write_shortcut_archive(target, shortcut_backup_sources(),
                                      'user-dotfiles-before-shortcut', 256_000_000)
    # Verify both immutable archives one final time before any edit.
    if defaults:
        defaults = verify_shortcut_archive(FULL_DEFAULT_SNAPSHOT)
    snapshot = verify_shortcut_archive(target)
    return dict(backup_dir=str(target), backup_files=snapshot['files'],
                backup_bytes=snapshot['bytes'],
                default_backup_dir=defaults['path'] if defaults else '',
                default_backup_files=defaults['files'] if defaults else 0,
                backup_verified=True, operation=operation)


def shortcut_archive_status():
    """Read-only status, never imply an unverified archive is a valid backup."""
    if SHORTCUT_ARCHIVES.is_symlink() or FULL_DEFAULT_SNAPSHOT.is_symlink():
        return dict(count=0, latest='', defaults_present=False, directory=str(SHORTCUT_ARCHIVES),
                    health='unsafe', message='Backup path is a symlink. Inspection required.')
    present = SHORTCUT_ARCHIVES.is_dir()
    archives = sorted(p for p in SHORTCUT_ARCHIVES.iterdir()
                      if p.is_dir() and not p.is_symlink() and (p / 'manifest.json').is_file()) if present else []
    return dict(count=len(archives), latest=str(archives[-1]) if archives else '',
                defaults_present=FULL_DEFAULT_SNAPSHOT.is_dir() and
                                 (FULL_DEFAULT_SNAPSHOT / 'manifest.json').is_file(),
                directory=str(SHORTCUT_ARCHIVES),
                health='unverified' if archives else 'missing')


def verify_shortcut_backups():
    """Detailed verification report; allow CLI/UI use even with zero snapshots."""
    info = shortcut_archive_status()
    if info.get('health') == 'unsafe':
        raise ValueError(info['message'])
    if not info['defaults_present'] and not info['count']:
        raise ValueError('No Omarchy/dotfiles shortcut backup exists yet. Select "Create backup now", or confirm "Back up & apply" to create one before changing bindings.')
    if is_omarchy() and not info['defaults_present']:
        raise ValueError('Full default Omarchy backup is missing; verify cannot pass.')
    defaults = verify_shortcut_archive(FULL_DEFAULT_SNAPSHOT) if info['defaults_present'] else None
    archives = sorted(p for p in SHORTCUT_ARCHIVES.iterdir()
                      if p.is_dir() and not p.is_symlink() and (p / 'manifest.json').is_file()) if SHORTCUT_ARCHIVES.is_dir() else []
    if not archives:
        raise ValueError('Default Omarchy is backed up, but no user dotfiles snapshots exist. Select Create backup now.')
    verified = [verify_shortcut_archive(p) for p in archives]
    return dict(ok=True, count=len(verified), latest=verified[-1]['path'],
                latest_files=verified[-1]['files'], latest_bytes=verified[-1]['bytes'],
                default=defaults, default_files=defaults['files'] if defaults else 0,
                directory=str(SHORTCUT_ARCHIVES),
                message=f'Verified {len(verified)} user snapshots and {defaults["files"] if defaults else 0} Omarchy default files (SHA-256).')


def create_shortcut_backup_now():
    """User-triggered backup without mutating any Hyprland configuration."""
    snapshot = backup_before_shortcut_change('manual')
    report = verify_shortcut_backups()
    return dict(ok=True, **snapshot,
                count=report['count'], default_files=report['default_files'],
                directory=report['directory'],
                message='Backup created and verified. No shortcut was changed. ' + report['message'])


def snapshot_user_config():
    """Atomic, bounded, symlink-preserving backup of user desktop config trees."""
    if TREE_META.is_file():
        return verify_user_config()
    if META.is_file():
        raise ValueError('Cannot capture pre-install configuration after permanent integration. Revert with existing backup first.')
    if TREE_ROOT.exists() or TREE_ROOT.is_symlink() or TREE_META.is_symlink():
        raise ValueError('Incomplete user configuration backup exists; refusing overwrite.')
    target = TREE_ROOT.parent
    target.mkdir(parents=True, exist_ok=True, mode=0o700)
    stage = Path(tempfile.mkdtemp(prefix='.user-config-', dir=target))
    count, total, files = 0, 0, {}
    missing = []
    try:
        for section in BACKUP_CONFIG_DIRS:
            origin = CONFIG / section
            if origin.is_symlink():
                raise ValueError('Top-level configuration is symlinked; cannot safely snapshot: ' + str(origin))
            if not origin.exists():
                missing.append(section)
                continue
            if not origin.is_dir():
                raise ValueError('Expected directory: ' + str(origin))
            for entry in sorted(origin.rglob('*')):
                relative = Path(section) / entry.relative_to(origin)
                if len(relative.parts) > 18:
                    raise ValueError('Configuration directory nesting exceeds safe limit')
                dest = stage / relative
                if entry.is_symlink():
                    count += 1
                    link = str(entry.readlink())
                    dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                    dest.symlink_to(link)
                    files[relative.as_posix()] = dict(type='symlink', sha256=digest(link))
                elif entry.is_dir():
                    dest.mkdir(parents=True, exist_ok=True, mode=0o700)
                elif entry.is_file():
                    count += 1
                    size = entry.stat().st_size
                    total += size
                    if size > 50_000_000 or total > 256_000_000:
                        raise ValueError('User configuration snapshot exceeds 256 MB limit; no changes made.')
                    dest.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                    shutil.copyfile(entry, dest, follow_symlinks=False)
                    dest.chmod(0o600)
                    files[relative.as_posix()] = dict(type='file', sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),
                                                     mode=stat.S_IMODE(entry.stat().st_mode))
                else:
                    raise ValueError('Unsupported special config entry: ' + str(entry))
                if count > 12000:
                    raise ValueError('User config snapshot exceeds 12000 entries')
        stage.rename(TREE_ROOT)
        data = dict(version=2, source_config=str(CONFIG), files=files, missing=missing,
                    bytes=total, count=count, created_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()))
        save_atomic(TREE_META, json.dumps(data, indent=2) + '\n', 0o600)
        return dict(ok=True, count=count, bytes=total, missing=missing, path=str(TREE_ROOT))
    except Exception:
        if stage.is_dir():
            shutil.rmtree(stage)
        # Fail-closed; preserve a moved snapshot for inspection rather than
        # declaring a partial copy to be a valid backup.
        raise


def verify_user_config():
    if not TREE_META.is_file() or TREE_META.is_symlink() or not TREE_ROOT.is_dir() or TREE_ROOT.is_symlink():
        raise ValueError('Full user configuration snapshot is missing or incomplete')
    data = json.loads(TREE_META.read_text(encoding='utf-8'))
    if data.get('version') != 2 or not isinstance(data.get('files'), dict):
        raise ValueError('Unknown user config backup manifest')
    for relative, record in data['files'].items():
        path_rel = Path(relative)
        if path_rel.is_absolute() or '..' in path_rel.parts or path_rel.parts[0] not in BACKUP_CONFIG_DIRS:
            raise ValueError('Invalid configuration backup path: ' + relative)
        copy = TREE_ROOT / path_rel
        if record.get('type') == 'file':
            if copy.is_symlink() or not copy.is_file() or hashlib.sha256(copy.read_bytes()).hexdigest() != record['sha256']:
                raise ValueError('Config backup checksum mismatch: ' + relative)
        elif record.get('type') == 'symlink':
            if not copy.is_symlink() or digest(str(copy.readlink())) != record['sha256']:
                raise ValueError('Config symlink snapshot mismatch: ' + relative)
        else:
            raise ValueError('Unknown backup entry type: ' + relative)
    return dict(ok=True, count=len(data['files']), bytes=data.get('bytes', 0), missing=data.get('missing', []), path=str(TREE_ROOT))


def verify_omarchy_backup(require_complete=True):
    if not OMARCHY_BACKUP_META.is_file() or OMARCHY_BACKUP_META.is_symlink():
        raise ValueError('Original Omarchy backup metadata missing')
    data = json.loads(OMARCHY_BACKUP_META.read_text(encoding='utf-8'))
    omarchy_folder = OMARCHY_BACKUP_META.parent / 'omarchy-default-hypr'
    for name, expected in data.get('files', {}).items():
        rel = Path(name)
        if rel.is_absolute() or '..' in rel.parts:
            raise ValueError('Invalid Omarchy backup path')
        copy = omarchy_folder / rel
        if not copy.is_file() or copy.is_symlink() or digest(copy.read_text(encoding='utf-8')) != expected:
            raise ValueError('Default Omarchy snapshot checksum mismatch: ' + name)
    for label, record in data.get('user_files', {}).items():
        copy = OMARCHY_BACKUP_META.parent / (label + '.original')
        if not copy.is_file() or digest(copy.read_text(encoding='utf-8')) != record.get('sha256'):
            raise ValueError('Original startup config backup missing or damaged: ' + label)
    full = verify_user_config() if TREE_META.is_file() else None
    if require_complete and not full:
        raise ValueError('Full user config snapshot not ready; cannot enable permanent integration')
    return dict(ok=True, default_files=len(data.get('files', {})), full=bool(full), user_files=full.get('count', 0) if full else 0)


def preserve_before_revert():
    """Keep pre-revert managed configs, so reverting never discards edits."""
    history = STATE / 'revert-history'
    history.mkdir(parents=True, exist_ok=True, mode=0o700)
    folder = Path(tempfile.mkdtemp(prefix='pre-revert-', dir=history))
    for label, location in [('hyprland', MAIN), ('bindings', BINDINGS)]:
        if location.is_file() and not location.is_symlink():
            copy = folder / (label + '.lua')
            shutil.copyfile(location, copy)
            copy.chmod(0o600)
    return str(folder)


def backup_omarchy():
    """Take an immutable local snapshot. Does not change session startup."""
    if not is_omarchy():
        raise ValueError('Omarchy Quattro Lua session not detected; no automatic backup created.')
    if META.exists() and not OMARCHY_BACKUP_META.exists():
        raise ValueError('Permanent mode already active, but its original backup is missing. Refusing to snapshot modified configs.')
    if OMARCHY_BACKUP_META.exists():
        info = json.loads(OMARCHY_BACKUP_META.read_text(encoding='utf-8'))
        if not TREE_META.exists() and not META.exists():
            snapshot_user_config()  # upgrade an earlier incomplete preinstall backup
        verified = verify_omarchy_backup(require_complete=not META.exists())
        return {'ok': True, 'created': False, 'backup_dir': str(OMARCHY_BACKUP_META.parent),
                'message': 'Verified original Omarchy + user configuration snapshots are preserved.',
                'verification': verified, 'snapshot': info}
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
        snapshot_user_config()
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
    # Omarchy Quattro variants disagree on whether o.rebind exists. The
    # portable documented approach is to explicitly unbind, then o.bind.
    # Unbind both the former key and new key for a remap, so existing defaults
    # on either combination cannot execute alongside RusticQ's action.
    for r in remaps.values():
        unbind(r['from'])
        unbind(r['to'])
        binds.append('o.bind(' + ', '.join(json.dumps(v) for v in (r['to'], r['label'], r['command'])) + ')')
    for act in ACTIONS:
        if act not in mapping:
            continue
        combo = mapping[act]
        unbind(combo)
        command = 'quickshell ipc -p ' + shlex.quote(str(target_shell)) + ' call rusticq dispatch ' + shlex.quote(act)
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
    archive = backup_before_shortcut_change('remap')
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
    except Exception as error:
        restore_bindings_after_rejected_reload(content, error)
    save_atomic(REMAPS, json.dumps(updated_map, indent=2) + '\n')
    save_atomic(SHORTCUT_BACKUPS, json.dumps(old_backups, indent=2) + '\n')
    return {'ok': True, 'message': item['from'] + ' → ' + dest + '. Original line preserved. ' + msg, 'remap_id': item['id'], **archive}


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
    archive = backup_before_shortcut_change('remap-revert')
    save_atomic(BINDINGS, updated)
    try:
        msg = run_hypr_reload()
    except Exception as error:
        restore_bindings_after_rejected_reload(current, error)
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
    return {'ok': True, 'message': 'Restored original ' + removed['from'] + ' binding at ' + removed['file'] + ':' + str(removed['line']) + '. ' + msg, **archive}


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
    # Keep prior binding snapshots in the audit record even after reassignment.
    updated = write_shortcuts(mapping, content)
    archive = backup_before_shortcut_change('shortcut')
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    original_backup = STATE / 'shortcut-original.txt'
    if not original_backup.exists():
        save_atomic(original_backup, remove_block(content) if START in content else content)
    save_atomic(BINDINGS, updated)
    try:
        reload_message = run_hypr_reload()
    except Exception as error:
        restore_bindings_after_rejected_reload(content, error)
    save_atomic(SHORTCUTS, json.dumps(mapping, indent=2) + '\n')
    save_atomic(SHORTCUT_BACKUPS, json.dumps(new_backups, indent=2) + '\n')
    return {'ok': True, 'message': f'{key} → {ACTIONS[action]}. Original lines backed up. ' + reload_message, 'shortcut': key, 'action': action, **archive}


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
    archive = backup_before_shortcut_change('shortcut-revert')
    save_atomic(BINDINGS, updated)
    try:
        result = run_hypr_reload()
    except Exception as error:
        restore_bindings_after_rejected_reload(current, error)
    if changed:
        save_atomic(SHORTCUTS, json.dumps(changed, indent=2) + '\n')
    elif SHORTCUTS.exists():
        SHORTCUTS.unlink()
    # Preserve saved originals for historical audit/recovery even after restore.
    # Only the active override map is removed.
    # Original default bindings are revealed again after hl.unbind is removed.
    # No user/default Lua source lines were ever rewritten.
    return {'ok': True, 'message': ('Restored ' + (removed_key or 'all shortcuts') + '. ' + result), **archive}


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



def installed_shell_processes():
    """Return live Quickshell PIDs whose argv uses the installed shell directory.

    A restored Omarchy autostart does NOT stop the still-running RusticQ from
    the previous login, so moving its files without checking can break it.
    Ignore processes that cannot be inspected (permission / exited races).
    """
    users = []
    proc_root = Path('/proc')
    if not proc_root.is_dir():
        return users
    for proc in proc_root.iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            raw = (proc / 'cmdline').read_bytes()
        except (OSError, PermissionError):
            continue
        args = [part.decode('utf-8', 'replace') for part in raw.split(b'\0') if part]
        if not args:
            continue
        executable = Path(args[0]).name
        if executable not in ('quickshell', 'qs', 'quickshell-qt6'):
            continue
        target = str(DATA)
        if any(arg == target or arg.startswith(target + '/') for arg in args[1:]):
            users.append(int(proc.name))
    return sorted(users)


def stale_shell_summary():
    """Pure status: distinguish an orphan directory from an in-use shell."""
    if DATA.is_symlink():
        return 'symlink', 'Installed-shell path is a symlink and will never be moved automatically.'
    if not DATA.exists():
        return 'absent', 'No previous installed shell remains.'
    if not DATA.is_dir():
        return 'not_directory', 'Installed-shell path is not a directory; inspect it manually.'
    users = installed_shell_processes()
    if users:
        return 'in_use', ('A Quickshell process is still running from this folder (PID ' +
                           ', '.join(map(str, users)) + '). Log out and log back into Omarchy '
                           'before reinstalling; existing files are untouched.')
    recognizable = (DATA / 'shell.qml').is_file() and (DATA / 'scripts/rustiq-desktop-integration.py').is_file()
    return ('known' if recognizable else 'partial',
            'Previous installed shell can be archived in full after explicit ENABLE RUSTICQ confirmation. '
            'An incomplete layout is preserved as-is; no files are deleted.')


def park_unmanaged_leftovers():
    """Archive old installed-shell files to private history (never delete).

    Once the user explicitly confirms ENABLE RUSTICQ and backup verification
    succeeds, the *exact* known installed-shell path may contain an incomplete
    or GitHub-updated tree. The old check required two specific files and
    incorrectly blocked reinstall. Archiving it is safe if the directory is
    real, not still in use, and the old manifest/startup hook is absent.
    """
    if META.exists() or START in read_file(MAIN):
        raise ValueError('RusticQ startup still appears installed; use Restore first.')
    candidates = [path for path in (SHIM, STARTER, DATA) if path.exists() or path.is_symlink()]
    if not candidates:
        return []
    for path in candidates:
        if path.is_symlink():
            raise ValueError('Unsafe symlinked stale integration file: ' + str(path))
        if path == DATA:
            status, detail = stale_shell_summary()
            if status not in ('known', 'partial'):
                raise ValueError('Cannot archive old installed shell at ' + str(path) + '. ' + detail)
        elif not path.is_file():
            raise ValueError('Unknown stale integration path: ' + str(path))
        elif path == SHIM and ('default.hypr' not in read_file(path) and 'hl.exec_cmd' not in read_file(path)):
            raise ValueError('Unrecognized stale autostart shim; backup and inspect it manually.')
        elif path == STARTER and 'quickshell' not in read_file(path):
            raise ValueError('Unrecognized stale shell starter; backup and inspect it manually.')
    history_root = STATE / 'stale-install-history'
    if history_root.is_symlink() or (history_root.exists() and not history_root.is_dir()):
        raise ValueError('Unsafe stale-install history path: ' + str(history_root))
    history = history_root / (time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()) + '-' + str(time.time_ns()))
    history.mkdir(parents=True, mode=0o700)
    parked = []
    try:
        for path in candidates:
            destination = history / ('shell' if path == DATA else path.name)
            path.rename(destination)
            parked.append((path, destination))
    except Exception:
        for original, destination in reversed(parked):
            destination.rename(original)
        raise
    return parked


def reinstate_parked_on_failure(parked):
    for original, saved in reversed(parked):
        if saved.exists() and not original.exists():
            saved.rename(original)


def _enable_permanent(token):
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
    # A previous interrupted restore may leave orphaned launcher/shell files.
    # Archive them *after* backup verification instead of blocking reinstall.
    record_install_progress('enable', 7, 'Compatibility checks passed')
    backup_result = backup_omarchy()
    record_install_progress('enable', 32, 'Omarchy and user configuration backed up')
    verify_omarchy_backup(require_complete=True)
    record_install_progress('enable', 43, 'Backup checksums verified')
    originals = backup_result['snapshot']['user_files']
    # Compute/validate all config transformations before parking old directories.
    parked = []
    copied_new_shell = False
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
        parked = park_unmanaged_leftovers()
        copied_new_shell = True  # Includes a possible incomplete copytree.
        safe_copy_shell()
        record_install_progress('enable', 67, 'RusticQ shell files copied')
        save_atomic(SHIM, patched_autostart)
        save_atomic(STARTER, '#!/bin/sh\nexec ' + shlex.quote(shutil.which('quickshell') or '/usr/bin/quickshell') + ' -n -p ' + shlex.quote(str(DATA)) + '\n', 0o700)
        record_install_progress('enable', 81, 'Private next-login launcher created')
        save_atomic(MAIN, new_main)
        if installed_bindings != original_bindings:
            save_atomic(BINDINGS, installed_bindings)
        record_install_progress('enable', 92, 'Hyprland user configuration updated')
        metadata['bindings_modified'] = installed_bindings != original_bindings
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
        # Only remove a NEW tree from this transaction. A failed parking step
        # must never cause a pre-existing user directory to be deleted.
        if copied_new_shell and DATA.is_dir() and not DATA.is_symlink():
            shutil.rmtree(DATA)
        reinstate_parked_on_failure(parked)
        raise
    record_install_progress('enable', 100, 'Installed for next login — finished', 'completed')
    return {'ok': True, 'message': 'Installation 100% complete. Startup is prepared for next login; current session unchanged.' + (' Previous interrupted installation files were safely archived.' if parked else ''), 'backup_dir': str(STATE / 'backup'), 'recovered_files': [str(saved) for _old, saved in parked], 'integration': integration_report()}


def enable_permanent(token):
    try:
        return _enable_permanent(token)
    except Exception as error:
        # Never mask the original security/backup/rollback failure.
        try:
            if INSTALL_PROGRESS.is_file() and not META.is_file():
                last = json.loads(INSTALL_PROGRESS.read_text(encoding='utf-8'))
                if last.get('operation') == 'enable' and last.get('state') == 'running':
                    record_install_progress('enable', min(99, last.get('percent', 0)),
                                            'Installation stopped', 'failed', str(error))
        except (OSError, ValueError, TypeError):
            pass
        raise


def _revert_permanent(token):
    if token != 'RESTORE OMARCHY':
        raise ValueError('Type RESTORE OMARCHY to authorize reverting startup.')
    meta = load_meta()
    if not meta:
        return {'ok': True, 'message': 'Permanent RusticQ integration is not installed.'}
    verify_omarchy_backup(require_complete=False)  # older RC5 snapshots stay revertible
    existing = read_file(MAIN, required=True)
    if digest(existing) != meta.get('main_applied_hash'):
        # Allow external edits outside the generated block if managed content is still exact.
        try:
            original = remove_block(existing)
        except ValueError:
            raise ValueError('Hyprland config changed since install. Manual merge needed; backup was preserved.')
    else:
        original = (STATE / 'backup/hyprland.original').read_text(encoding='utf-8')
    # Preserve *current* managed configs before writing, including any
    # personal changes since activation. Never force-restore entire user dirs.
    record_install_progress('revert', 30, 'Saving pre-revert history')
    history = preserve_before_revert()
    # Keep shortcut overrides independent from permanent shell integration.
    bindings = read_file(BINDINGS)
    save_atomic(MAIN, original)
    META.unlink()
    record_install_progress('revert', 72, 'Omarchy startup configuration restored')
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
    msg = 'Omarchy startup restored for next login. Original backups retained; pre-revert configs saved in ' + history + '. Shortcut overrides kept independent.'
    if parked is not None:
        msg += ' Previous RusticQ install parked at ' + str(parked)
    record_install_progress('revert', 100, 'Omarchy startup restored for next login', 'completed', msg)
    return {'ok': True, 'message': msg, 'integration': integration_report()}



def record_install_progress(operation, percent, phase, state='running', message=''):
    """Atomic, read-only-to-UI checkpoint. Percent counts completed steps, not time."""
    if operation not in ('enable', 'revert') or state not in ('running', 'completed', 'failed'):
        raise ValueError('Invalid integration progress update')
    payload = dict(version=1, operation=operation, percent=max(0, min(int(percent), 100)),
                   phase=phase, state=state, message=str(message)[:400], updated=int(time.time()))
    save_atomic(INSTALL_PROGRESS, json.dumps(payload, ensure_ascii=False, indent=2) + '\n')


def integration_report():
    """Actual on-disk completion, distinct from current-session activation.

    A previous version had no checkpoint. Existing valid installs are reported
    complete based on tangible generated files instead of a fabricated timer.
    """
    meta = load_meta()
    progress = {}
    if INSTALL_PROGRESS.is_file() and not INSTALL_PROGRESS.is_symlink():
        try:
            candidate = json.loads(INSTALL_PROGRESS.read_text(encoding='utf-8'))
            if isinstance(candidate, dict) and candidate.get('version') == 1:
                progress = candidate
        except (OSError, ValueError, UnicodeError):
            progress = {}
    permanent = bool(meta)
    restoring = progress.get('operation') == 'revert' and progress.get('state') == 'running'
    try:
        main_managed = permanent and START in read_file(MAIN)
    except (OSError, ValueError, UnicodeError):
        main_managed = False
    shell_copied = (DATA / 'shell.qml').is_file() and not DATA.is_symlink()
    shim_created = SHIM.is_file() and not SHIM.is_symlink()
    starter_created = STARTER.is_file() and not STARTER.is_symlink()
    backups_created = OMARCHY_BACKUP_META.is_file() and TREE_META.is_file()
    checks = dict(manifest=permanent, hyprland=main_managed,
                  shim=shim_created, starter=starter_created, shell=shell_copied,
                  backups=backups_created)
    complete = permanent and all(checks.values())
    backup_folder = STATE / 'backup'
    binding_modified = bool(meta.get('bindings_modified', False)) if permanent else False
    # Older manifests did not record bindings_modified; only report that their
    # bindings may be managed, never claim this installer definitely touched it.
    changes = [
        dict(path=str(MAIN), action='Modified' if permanent else 'Not changed',
             detail='Hyprland Lua startup hook', present=main_managed),
        dict(path=str(BINDINGS), action=('Modified' if binding_modified else 'Possibly updated' if permanent else 'Not changed'),
             detail='Shortcut path repointed only if a managed RusticQ binding existed',
             present=BINDINGS.is_file() and not BINDINGS.is_symlink()),
        dict(path=str(SHIM), action='Created' if permanent else 'Not created',
             detail='Private Omarchy autostart override for next login', present=shim_created),
        dict(path=str(STARTER), action='Created' if permanent else 'Not created',
             detail='Shell starter used by Hyprland on next login', present=starter_created),
        dict(path=str(DATA), action='Copied' if permanent else 'Not copied',
             detail='Installed RusticQ source tree (contains shell.qml)', present=shell_copied),
        dict(path=str(META), action='Created' if permanent else 'Not created',
             detail='Integration manifest and restore reference', present=META.is_file()),
        dict(path=str(backup_folder), action='Snapshot' if backup_folder.is_dir() else 'Missing',
             detail='Original Omarchy and user-configuration backups; never removed by install', present=backup_folder.is_dir()),
        dict(path=str(DEFAULT_AUTOSTART), action='Read only',
             detail='Original Omarchy file is not edited', present=DEFAULT_AUTOSTART.is_file()),
    ]
    if permanent and not restoring:
        if complete:
            return dict(ok=True, operation='enable', state='installed', percent=100,
                        phase='Installation completed — ready for next login',
                        message='All required generated files are present. The current desktop session is not automatically replaced.',
                        next_login=True, session_active='unverified', checks=checks, changes=changes)
        failed = [name for name, passed in checks.items() if not passed]
        return dict(ok=False, operation='enable', state='incomplete', percent=90,
                    phase='Installation incomplete — files need attention',
                    message='Missing or invalid installation items: ' + ', '.join(failed),
                    next_login=False, session_active='unverified', checks=checks, changes=changes)
    if progress.get('state') == 'running':
        elapsed = time.time() - (progress.get('updated') or 0)
        state = 'interrupted' if elapsed > 90 else 'running'
        return dict(ok=False, operation=progress.get('operation', 'enable'), state=state,
                    percent=min(99, max(0, int(progress.get('percent', 0)))),
                    phase=progress.get('phase', 'Integration in progress'),
                    message=('No recent progress; the operation may have been interrupted.' if state == 'interrupted' else progress.get('message', '')),
                    next_login=False, session_active='unverified', checks=checks, changes=changes)
    if progress.get('state') == 'failed':
        return dict(ok=False, operation=progress.get('operation', 'enable'), state='failed',
                    percent=min(99, max(0, int(progress.get('percent', 0)))),
                    phase=progress.get('phase', 'Integration failed'), message=progress.get('message', ''),
                    next_login=False, session_active='unverified', checks=checks, changes=changes)
    if progress.get('state') == 'completed' and progress.get('operation') == 'revert':
        for row in changes:
            if row['path'] == str(MAIN):
                row['action'] = 'Restored'
                row['detail'] = 'Original Omarchy Lua startup restored in the user config'
            elif row['path'] == str(DATA):
                row['action'] = 'Archived'
                row['detail'] = 'Installed copy moved to shell-previous* instead of deleted'
            elif row['path'] in (str(SHIM), str(STARTER), str(META)):
                row['action'] = 'Removed'
            elif row['path'] == str(backup_folder):
                row['action'] = 'Preserved'
        return dict(ok=True, operation='revert', state='restored', percent=100,
                    phase='Omarchy startup restored', message=progress.get('message', ''),
                    next_login=True, session_active='unverified', checks=checks, changes=changes)
    return dict(ok=True, operation='enable', state='not_installed', percent=0,
                phase='Not installed permanently', message='No persistent RusticQ integration is installed.',
                next_login=False, session_active='unverified', checks=checks, changes=changes)


def revert_permanent(token):
    try:
        return _revert_permanent(token)
    except Exception as error:
        try:
            if INSTALL_PROGRESS.is_file():
                last = json.loads(INSTALL_PROGRESS.read_text(encoding='utf-8'))
                if last.get('operation') == 'revert' and last.get('state') == 'running':
                    record_install_progress('revert', min(99, last.get('percent', 0)),
                                            'Restore stopped', 'failed', str(error))
        except (OSError, ValueError, TypeError):
            pass
        raise


def backup_health():
    # Fast read-only summary on every Settings refresh; checksum verification is
    # mandatory before both enable and revert, not every status refresh.
    if not OMARCHY_BACKUP_META.is_file():
        return dict(ok=False, message='No original Omarchy snapshot yet', full=False)
    try:
        data = json.loads(OMARCHY_BACKUP_META.read_text(encoding='utf-8'))
        full = TREE_META.is_file() and TREE_ROOT.is_dir()
        tree = json.loads(TREE_META.read_text(encoding='utf-8')) if full else {}
        return dict(ok=full, full=full, defaults=len(data.get('files', {})),
                    user_files=tree.get('count', 0),
                    message='Snapshot metadata ready; checksums checked on enable/revert' if full else
                            'Legacy backup: full preinstall user-tree snapshot unavailable')
    except (ValueError, OSError, KeyError, json.JSONDecodeError) as error:
        return dict(ok=False, full=False, message=str(error))




def reinstall_readiness():
    """Non-mutating diagnosis for Restore -> Enable workflows."""
    manifest = META.is_file() and not META.is_symlink()
    main = read_file(MAIN)
    leftovers = [str(path) for path in (SHIM, STARTER, DATA) if path.exists() or path.is_symlink()]
    managed = START in main
    if manifest or managed:
        message = 'Permanent integration is still registered. Restore before reinstalling.'
    elif leftovers:
        message = ('Previous files detected: ' + ', '.join(leftovers) +
                   '. On confirmed install RusticQ validates and archives recognizable leftovers after backup verification.')
    else:
        message = 'No stale permanent-install files. Type ENABLE RUSTICQ to reinstall.'
    shell_state, shell_note = stale_shell_summary()
    if shell_state not in ('absent',):
        message += ' ' + shell_note
    return dict(ready=not (manifest or managed) and shell_state not in ('symlink', 'not_directory', 'in_use'),
                stale_files=leftovers, shell_state=shell_state, shell_note=shell_note,
                backup_metadata_present=OMARCHY_BACKUP_META.is_file(), message=message)


def status():
    manifest = load_meta()
    bindings = read_file(BINDINGS)
    return {'ok': True, 'permanent': bool(manifest), 'shortcut_managed': START in bindings, 'shortcuts': load_shortcuts(), 'shortcut_backups': load_shortcut_backups(), 'shortcut_archives': shortcut_archive_status(), 'remaps': load_remaps(), 'backup_dir': str(STATE / 'backup'), 'omarchy_backup_ready': backup_health()['ok'], 'backup_health': backup_health(),
            'installed_shell': str(DATA), 'omarchy_source': str(DEFAULT_AUTOSTART), 'compatibility': preview(), 'integration': integration_report(), 'reinstall': reinstall_readiness()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['status', 'integration-progress', 'preview', 'bindings', 'actions', 'shortcut', 'shortcut-revert', 'remap', 'remap-revert', 'backup-omarchy', 'verify-backup', 'verify-shortcut-backups', 'create-shortcut-backup', 'list-shortcut-backups', 'enable', 'revert'])
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
            'integration-progress': integration_report,
            'preview': preview,
            'bindings': catalogue,
            'actions': actions_catalogue,
            'shortcut': lambda: apply_keybinding(args.key, args.action),
            'shortcut-revert': lambda: restore_shortcut(None if args.all else args.action),
            'remap': lambda: remap_binding(args.file, args.line, args.source_hash, args.key),
            'remap-revert': lambda: restore_remap(args.remap_id),
            'backup-omarchy': backup_omarchy,
            'verify-shortcut-backups': verify_shortcut_backups,
            'create-shortcut-backup': create_shortcut_backup_now,
            'list-shortcut-backups': lambda: dict(ok=True, **shortcut_archive_status()),
            'verify-backup': lambda: dict(ok=True, verification=verify_omarchy_backup(require_complete=not META.exists()), message='Original backup integrity verified'),
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
