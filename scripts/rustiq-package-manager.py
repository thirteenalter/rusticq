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


def resolve_desktop(entry_id, display_name='', search_dirs=None):
    """Find the owning pacman package for a real desktop file, never guess from an app label.

    Quickshell DesktopEntry.id can contain a basename, an XDG-style id or be
    empty for some application sources. A unique .desktop Name is a safe fallback
    only when the actual file is owned by exactly one pacman package.
    """
    import configparser
    if not isinstance(entry_id, str) or len(entry_id) > 260 or any(c in entry_id for c in ('/', '\x00', '\n', '\r')) or '..' in entry_id:
        raise ValueError('Invalid desktop entry ID')
    if not isinstance(display_name, str) or len(display_name) > 260:
        raise ValueError('Invalid application name')
    candidates = []
    filenames = [entry_id] if entry_id.endswith('.desktop') else [entry_id + '.desktop']
    filenames.append(entry_id.replace('/', '-') + '.desktop')
    if search_dirs is None:
        search_dirs = (Path('/usr/share/applications'), Path('/usr/local/share/applications'))
    for directory in search_dirs:
        directory = Path(directory)
        if not directory.is_dir():
            continue
        for path in directory.glob('*.desktop'):
            if path.is_symlink():
                continue
            if path.name in filenames:
                candidates.insert(0, path)
                continue
            if not display_name:
                continue
            try:
                parser = configparser.ConfigParser(interpolation=None, strict=False)
                parser.optionxform = str
                parser.read(path, encoding='utf-8')
                if parser.has_section('Desktop Entry') and parser.get('Desktop Entry', 'Name', fallback='').casefold() == display_name.casefold():
                    candidates.append(path)
            except (OSError, UnicodeError, configparser.Error):
                continue
    owners = set()
    for path in candidates:
        result = run(['pacman', '-Qqo', str(path)])
        if result.returncode == 0:
            for owner in result.stdout.splitlines():
                owner = owner.strip()
                if PACKAGE.fullmatch(owner):
                    owners.add(owner)
    if len(owners) == 1:
        return next(iter(owners))
    if len(owners) > 1:
        raise RuntimeError('Multiple pacman packages match this app. Search the exact package below instead.')
    raise RuntimeError('This app has no resolvable pacman owner (possibly AUR, Flatpak, AppImage or local). Search its package manually or manage it through its original installer.')


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
    if len(argv) in (2, 3) and argv[0] == 'resolve-desktop':
        return {'ok': True, 'package': resolve_desktop(argv[1], argv[2] if len(argv) == 3 else '')}
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
