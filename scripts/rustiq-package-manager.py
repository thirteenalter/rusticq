#!/usr/bin/env python3
"""Explicit, interactive pacman package operations for RusticQ.

Never runs on page load. The caller must confirm the exact package name.
No arbitrary commands, shell evaluation, force-removes or --noconfirm.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

PACKAGE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9@._+:-]{0,127}$")
DESKTOP = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._+-]{0,160}(?:\.desktop)?$")


def run(args, timeout=10):
    return subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)


def validate_package(value):
    if not isinstance(value, str) or not PACKAGE.fullmatch(value):
        raise ValueError("Invalid package name")
    return value


def validate_request(action, package):
    if action not in ("install", "remove"):
        raise ValueError("Unsupported package operation")
    package = validate_package(package)
    if not shutil.which("pacman"):
        raise RuntimeError("pacman not available")
    if action == "remove":
        result = run(["pacman", "-Qq", package])
        if result.returncode != 0 or result.stdout.strip() != package:
            raise RuntimeError("This package is not installed")
    else:
        result = run(["pacman", "-Si", package])
        if result.returncode != 0:
            raise RuntimeError("Package not found in configured pacman repositories. AUR/Flatpak/AppImage are not supported here.")
    return package


def resolve_desktop(entry_id):
    if not isinstance(entry_id, str) or not DESKTOP.fullmatch(entry_id) or '..' in entry_id:
        raise ValueError('Invalid desktop entry ID')
    filename = entry_id if entry_id.endswith('.desktop') else entry_id + '.desktop'
    # Only system desktop entries known to pacman; never guess installed package ownership.
    for directory in ['/usr/share/applications', '/usr/local/share/applications']:
        path = Path(directory) / filename
        if not path.is_file():
            continue
        result = run(['pacman', '-Qqo', str(path)])
        if result.returncode == 0:
            name = result.stdout.strip().splitlines()[0]
            if PACKAGE.fullmatch(name):
                return name
    raise RuntimeError('No pacman package owns this desktop entry. It may come from Flatpak, AppImage or a local install.')


def make_commands(action, package, omarchy=None):
    validate_package(package)
    if action == 'remove':
        # -R preserves configurations and refuses breaking dependencies.
        return [['sudo', 'pacman', '-R', '--', package]]
    if action != 'install':
        raise ValueError('Unsupported action')
    if omarchy is None:
        omarchy = shutil.which('omarchy') is not None
    if omarchy:
        # Omarchy's own update hook controls snapshots/migrations.
        return [['omarchy', 'update'], ['sudo', 'pacman', '-S', '--', package]]
    # Arch prohibits partial upgrades: perform full sync+upgrade with install.
    return [['sudo', 'pacman', '-Syu', '--', package]]


def choose_terminal():
    candidates = [
        ('ghostty', ['ghostty', '-e']),
        ('foot', ['foot', '-e']),
        ('kitty', ['kitty', '-e']),
        ('alacritty', ['alacritty', '-e']),
        ('wezterm', ['wezterm', 'start', '--']),
        ('konsole', ['konsole', '-e']),
        ('gnome-terminal', ['gnome-terminal', '--']),
        ('xterm', ['xterm', '-e']),
    ]
    for name, args in candidates:
        if shutil.which(name):
            return args
    raise RuntimeError('No supported terminal emulator found. Install Ghostty, foot, kitty, Alacritty, etc.')


def launch(action, package):
    validate_request(action, package)
    command = choose_terminal() + [sys.executable, str(Path(__file__).resolve()), 'apply', action, package]
    subprocess.Popen(command, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {'ok': True, 'message': 'Interactive terminal opened. This does not mean the package operation succeeded.'}


def apply(action, package):
    validate_request(action, package)
    steps = make_commands(action, package)
    print(f'RusticQ package operation: {action.upper()} {package}', flush=True)
    print('WARNING: Removing packages may affect your desktop. Proceed at your own risk.', flush=True)
    for index, command in enumerate(steps, 1):
        print(f'\nStep {index}/{len(steps)}: {" ".join(command)}', flush=True)
        result = subprocess.run(command, check=False)
        if result.returncode != 0:
            print(f'Operation halted, exit code: {result.returncode}', flush=True)
            input('Press Enter to close this terminal...')
            return result.returncode
    print('Operation finished. Refresh Installed Apps in RusticQ.', flush=True)
    input('Press Enter to close this terminal...')
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == 'resolve-desktop':
        return {'ok': True, 'package': resolve_desktop(argv[1])}
    if len(argv) != 3:
        raise ValueError('Expected operation and package')
    op, action, package = argv
    if op == 'launch':
        return launch(action, package)
    if op == 'inspect':
        validate_request(action, package)
        return {'ok': True, 'package': package, 'action': action, 'omarchy': shutil.which('omarchy') is not None}
    raise ValueError('Unsupported request')


if __name__ == '__main__':
    if len(sys.argv) == 4 and sys.argv[1] == 'apply':
        try:
            sys.exit(apply(sys.argv[2], sys.argv[3]))
        except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
            print('ERROR:', exc, flush=True)
            input('Press Enter to close this terminal...')
            sys.exit(1)
    try:
        print(json.dumps(main(sys.argv[1:])))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({'ok': False, 'message': str(exc)}))
        sys.exit(1)
