#!/usr/bin/env python3
"""Read-only RusticQ health report: python3 scripts/rusticq-doctor.py [doctor|status] [--json].

Reuses existing RusticQ helpers rather than starting duplicate monitoring services.
Never runs sudo, changes session services, launches programs, or writes configuration.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PROGRAMS = {
    'core': ['qs', 'hyprctl', 'python3'],
    'optional': ['nmcli', 'bluetoothctl', 'wpctl', 'playerctl', 'grim', 'slurp',
                 'wf-recorder', 'wl-copy', 'hyprsunset', 'pacman', 'busctl',
                 'hyprpicker', 'tesseract', 'notify-send', 'swww', 'awww'],
}


def execute(argv, timeout=3):
    try:
        return subprocess.run(argv, capture_output=True, text=True,
                              timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        return None


def entry(check_id, state, description, suggestion=''):
    return {'id': check_id, 'state': state, 'detail': description,
            'suggestion': suggestion}


def doctor(root=ROOT):
    root = Path(root)
    results = []
    for group, commands in PROGRAMS.items():
        for command in commands:
            available = shutil.which(command) is not None
            results.append(entry('binary.' + command, 'ok' if available else 'warn' if group == 'core' else 'skip',
                                 ('Available: ' if available else 'Not found: ') + command,
                                 '' if available else ('Required core runtime' if group == 'core' else 'Optional feature dependency')))
    wayland = bool(os.environ.get('WAYLAND_DISPLAY'))
    results.append(entry('wayland.session', 'ok' if wayland else 'skip',
                         'Wayland socket advertised' if wayland else 'No Wayland socket in this process environment',
                         '' if wayland else 'Run in the target Hyprland session for live checks'))
    result = execute(['hyprctl', '-j', 'monitors']) if shutil.which('hyprctl') else None
    if result and result.returncode == 0:
        try:
            monitors = json.loads(result.stdout)
            if isinstance(monitors, list):
                results.append(entry('hyprland.monitors', 'ok', f'{len(monitors)} monitor(s) reported'))
            else:
                results.append(entry('hyprland.monitors', 'warn', 'Unexpected Hyprland response'))
        except ValueError:
            results.append(entry('hyprland.monitors', 'warn', 'Invalid Hyprland monitors JSON'))
    else:
        results.append(entry('hyprland.monitors', 'skip', 'Live Hyprland monitor API unavailable'))
    for path in (root / 'shell.qml', root / 'config/SettingsStore.qml', root / 'scripts/rustiq-notification-doctor.py'):
        results.append(entry('source.' + path.name, 'ok' if path.is_file() else 'warn',
                             ('Found ' if path.is_file() else 'Missing ') + str(path.relative_to(root))))
    for name in ('user-settings.json', 'app-usage.json'):
        path = root / name
        if not path.is_file():
            results.append(entry('config.' + name, 'skip', 'No local ' + name + ' yet'))
            continue
        try:
            if path.is_symlink() or path.stat().st_size > 2_000_000:
                raise ValueError('Untrusted path or file exceeds safe size')
            data = json.loads(path.read_text())
            if not isinstance(data, dict):
                raise ValueError('Expected JSON object')
            results.append(entry('config.' + name, 'ok', 'Valid JSON object'))
        except (OSError, ValueError) as exc:
            results.append(entry('config.' + name, 'warn', str(exc),
                                 'Use rusticq-config-guard.py list/restore after reviewing saved snapshots'))
    notification_script = root / 'scripts/rustiq-notification-doctor.py'
    if notification_script.is_file() and shutil.which('busctl'):
        # Reuse the existing notification subsystem's bus-owner diagnostic; no new daemon.
        response = execute(['python3', str(notification_script)], timeout=5)
        if response and response.returncode == 0:
            try:
                status = json.loads(response.stdout)
                state = status.get('state', 'error')
                results.append(entry('dbus.notifications',
                                     'ok' if state in ('owned', 'free') else 'warn',
                                     status.get('owner', state), status.get('suggestion', '')))
            except (ValueError, AttributeError):
                results.append(entry('dbus.notifications', 'warn', 'Invalid notification doctor result'))
        else:
            results.append(entry('dbus.notifications', 'skip', 'Session D-Bus unavailable'))
    else:
        results.append(entry('dbus.notifications', 'skip', 'Notification diagnostic or busctl missing'))
    # A read-only check only; actual session integration is distro-controlled.
    portal = execute(['systemctl', '--user', 'is-active', 'xdg-desktop-portal.service']) if shutil.which('systemctl') else None
    portal_state = portal.stdout.strip() if portal else 'unknown'
    results.append(entry('portal.user', 'ok' if portal_state == 'active' else 'skip',
                         'xdg-desktop-portal: ' + (portal_state or 'unknown'),
                         'Inspect your compositor-specific portal backend if screen sharing fails'))
    for name in ('pipewire.service', 'wireplumber.service'):
        service = execute(['systemctl', '--user', 'is-active', name]) if shutil.which('systemctl') else None
        status = (service.stdout.strip() if service else 'unknown')
        results.append(entry('user.service.' + name, 'ok' if status == 'active' else 'skip',
                             f'{name}: {status or "unknown"}', 'Can be distro-managed' if status != 'active' else ''))
    # Feature-capability checks never spawn screenshot, color sampling or OCR.
    for feature, commands in {
        'launcher.emoji': ('wl-copy',),
        'launcher.wallpaper': ('swww', 'awww', 'hyprctl'),
        'launcher.color': ('hyprpicker', 'wl-copy'),
        'launcher.ocr': ('grim', 'slurp', 'tesseract', 'wl-copy'),
        'launcher.files': ('xdg-open',),
        'launcher.windows': ('hyprctl',),
    }.items():
        installed = [name for name in commands if shutil.which(name)]
        if feature == 'launcher.wallpaper':
            ready = any(shutil.which(x) for x in ('swww', 'awww', 'hyprctl'))
        else:
            ready = len(installed) == len(commands)
        results.append(entry(feature, 'ok' if ready else 'skip',
                             'Tools detected: ' + (', '.join(installed) or 'none'),
                             '' if ready else 'Install optional command(s) for the selected launcher action'))
    notes = root / 'scripts' / 'rusticq-notes.py'
    results.append(entry('notes.kanban', 'ok' if notes.is_file() else 'warn',
                         'Local note backend available' if notes.is_file() else 'Notes backend missing',
                         '' if notes.is_file() else 'Restore scripts/rusticq-notes.py'))
    for name in ('hyprlock', 'hypridle', 'polkit-gnome-authentication-agent-1', 'lxqt-policykit-agent'):
        present = shutil.which(name) is not None
        results.append(entry('integration.' + name, 'ok' if present else 'skip',
                             ('Found: ' if present else 'Not installed: ') + name,
                             'Do not start a second agent or idle daemon if Omarchy already manages one'))
    return {'schema': 1, 'project': 'RusticQ', 'mode': 'read-only', 'checks': results,
            'totals': {state: sum(1 for c in results if c['state'] == state)
                       for state in ('ok', 'warn', 'skip')}}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('command', choices=['doctor', 'status'], nargs='?', default='doctor')
    ap.add_argument('--json', action='store_true')
    args = ap.parse_args()
    result = doctor()
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return
    totals = result['totals']
    print(f"RusticQ doctor (read-only): {totals['ok']} OK / {totals['warn']} warnings / {totals['skip']} unavailable")
    if args.command == 'doctor':
        for check in result['checks']:
            print(f"[{check['state'].upper():4}] {check['id']}: {check['detail']}")
            if check['suggestion'] and check['state'] != 'ok':
                print('       ' + check['suggestion'])


if __name__ == '__main__':
    main()
