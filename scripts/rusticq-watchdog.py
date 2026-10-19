#!/usr/bin/env python3
"""Install an OPTIONAL systemd user unit for restart-on-failure shell supervision.

Safe policy: never enable/start a second desktop shell. The user must first
remove any conflicting Omarchy/Hyprland autostart and then explicitly enable
rusticq.service using systemctl --user. Restart bursts are limited.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import stat

UNIT = '''[Unit]
Description=RusticQ Quickshell (optional, single owner)
Documentation=https://github.com/thirteenalter/rusticq
After=graphical-session.target
PartOf=graphical-session.target
StartLimitIntervalSec=90
StartLimitBurst=3

[Service]
Type=simple
ExecStart=%h/.local/bin/rusticq
Restart=on-failure
RestartSec=5
Slice=app.slice

[Install]
WantedBy=graphical-session.target
'''


def status(home=None):
    root = Path(home) if home else Path.home()
    target = root / '.config/systemd/user/rusticq.service'
    if target.is_symlink():
        return {'installed': False, 'warning': 'Unexpected unit symlink: inspect manually', 'enabled': None}
    contents = target.read_text() if target.is_file() else ''
    return {'installed': contents == UNIT, 'custom_unit_present': bool(contents and contents != UNIT),
            'unit_path': str(target), 'enabled': None,
            'message': 'Status does not imply the service is enabled or running. This tool never starts it.'}


def install(home=None, confirmation=''):
    if confirmation != 'INSTALL WATCHDOG':
        raise ValueError('Exact INSTALL WATCHDOG confirmation required')
    root = Path(home) if home else Path.home()
    target = root / '.config/systemd/user/rusticq.service'
    if target.is_symlink():
        raise ValueError('Refusing unit symlink')
    if target.exists():
        if target.read_text() != UNIT:
            raise ValueError('Existing custom rusticq.service preserved; refuse overwrite')
        return {'installed': True, 'changed': False, 'unit_path': str(target)}
    target.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    with target.open('x', encoding='utf-8') as out:
        os.chmod(target, 0o600)
        out.write(UNIT)
    return {'installed': True, 'changed': True, 'unit_path': str(target),
            'message': 'Unit installed but NOT enabled, started, or daemon-reloaded; check conflicting shell startup first.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['status', 'install'])
    parser.add_argument('--confirm', default='')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    try:
        value = status() if args.action == 'status' else install(confirmation=args.confirm)
        print(json.dumps(value) if args.json else json.dumps(value, indent=2))
    except (ValueError, OSError) as error:
        print(json.dumps({'ok': False, 'error': str(error)}))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
