#!/usr/bin/env python3
"""Safe user-level font management and optional native file chooser for RusticQ.
No shell interpolation, package manager changes, or system-font mutation.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

HOME = Path.home().resolve()
FONT_EXT = {'.ttf', '.otf', '.ttc', '.woff', '.woff2'}
IMAGE_EXT = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'}


def emit(ok=True, **kwargs):
    print(json.dumps({'ok': bool(ok), **kwargs}, ensure_ascii=False))
    return 0 if ok else 1


def font_families():
    if not shutil.which('fc-list'):
        return emit(False, message='fontconfig (fc-list) is unavailable', families=[])
    try:
        result = subprocess.run(['fc-list', '--format=%{family}\n'], capture_output=True,
                                text=True, timeout=12, check=True)
        families = sorted({name.strip() for line in result.stdout.splitlines()
                           for name in line.split(',') if name.strip()}, key=str.casefold)
        return emit(families=families[:500])
    except (OSError, subprocess.SubprocessError) as exc:
        return emit(False, message=str(exc), families=[])


def choose(kind):
    if kind not in ('wallpaper', 'font', 'settings'):
        return emit(False, message='Invalid file picker type')
    options = [('zenity', ['zenity', '--file-selection', f'--title=Choose {kind}']),
               ('kdialog', ['kdialog', '--getopenfilename', str(HOME)]),
               ('yad', ['yad', '--file-selection', f'--title=Choose {kind}'])]
    for name, args in options:
        if shutil.which(name):
            try:
                result = subprocess.run(args, capture_output=True, text=True, timeout=180)
            except (OSError, subprocess.TimeoutExpired) as exc:
                return emit(False, message=str(exc))
            if result.returncode != 0 or not result.stdout.strip():
                return emit(False, cancelled=True, message='Selection cancelled')
            path = Path(result.stdout.strip()).expanduser()
            try:
                if path.is_symlink():
                    return emit(False, message='Symlinked settings files are not supported')
                resolved = path.resolve(strict=True)
                if kind != 'settings':
                    resolved.relative_to(HOME)
            except (OSError, ValueError):
                return emit(False, message='Choose an existing local file' if kind == 'settings' else 'Select a file under your home folder')
            allowed = {'.json'} if kind == 'settings' else IMAGE_EXT if kind == 'wallpaper' else FONT_EXT
            if not resolved.is_file() or resolved.suffix.lower() not in allowed:
                return emit(False, message='Unsupported file type')
            return emit(path=str(resolved))
    return emit(False, message='Install zenity, kdialog or yad for native file picking')


def install_font(path):
    try:
        source = Path(path).expanduser().resolve(strict=True)
        source.relative_to(HOME)
    except (OSError, ValueError):
        return emit(False, message='Choose an existing font under your home directory')
    if not source.is_file() or source.suffix.lower() not in FONT_EXT:
        return emit(False, message='Choose a TTF, OTF, TTC, WOFF or WOFF2 font')
    if source.stat().st_size > 30 * 1024 * 1024:
        return emit(False, message='Font exceeds 30 MiB')
    target_dir = HOME / '.local' / 'share' / 'fonts' / 'rusticq'
    target_dir.mkdir(parents=True, exist_ok=True)
    destination = target_dir / source.name
    index = 1
    while destination.exists():
        destination = target_dir / f'{source.stem}-{index}{source.suffix}'
        index += 1
    shutil.copy2(source, destination)
    if shutil.which('fc-cache'):
        try:
            subprocess.run(['fc-cache', '-f', str(target_dir)], timeout=25, check=False,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            pass
    family = ''
    if shutil.which('fc-scan'):
        try:
            result = subprocess.run(['fc-scan', '--format=%{family}\n', str(destination)],
                                    capture_output=True, text=True, timeout=10)
            family = result.stdout.strip().splitlines()[0].split(',')[0] if result.stdout.strip() else ''
        except (OSError, subprocess.TimeoutExpired):
            pass
    return emit(path=str(destination), family=family,
                message='Font installed for this user. Some apps may need to restart.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['fonts', 'pick-wallpaper', 'pick-font', 'pick-settings', 'install-font'])
    parser.add_argument('path', nargs='?')
    args = parser.parse_args()
    if args.action == 'fonts':
        return font_families()
    if args.action == 'pick-wallpaper':
        return choose('wallpaper')
    if args.action == 'pick-font':
        return choose('font')
    if args.action == 'pick-settings':
        return choose('settings')
    if not args.path:
        return emit(False, message='Missing font file path')
    return install_font(args.path)


if __name__ == '__main__':
    sys.exit(main())
