#!/usr/bin/env python3
"""RusticQ manual wallpaper setter. Never executes a shell or rewrites Aether files."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ALLOWED_SUFFIXES = {'.jpg', '.jpeg', '.png', '.webp', '.bmp'}

def emit(ok, message, backend=''):
    print(json.dumps({'ok': ok, 'message': message, 'backend': backend}))
    return 0 if ok else 1

def run(argv):
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=16)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return False, str(exc)
    return (r.returncode == 0), (r.stderr or r.stdout).strip()[-260:]

def apply(path, backend):
    candidate = Path(path).expanduser()
    try:
        image = candidate.resolve(strict=True)
        home = Path.home().resolve()
        image.relative_to(home)
    except (OSError, ValueError):
        return emit(False, 'Choose an existing image inside your home directory.')
    if not image.is_file() or image.suffix.lower() not in ALLOWED_SUFFIXES:
        return emit(False, 'Unsupported image; use PNG, JPEG, WebP or BMP.')
    if image.stat().st_size > 70 * 1024 * 1024:
        return emit(False, 'Image exceeds 70 MiB.')
    backends = ['swww', 'awww', 'hyprpaper'] if backend == 'auto' else [backend]
    for b in backends:
        if b not in {'swww', 'awww', 'hyprpaper'} or not shutil.which(b):
            continue
        if b == 'swww':
            argv = ['swww','img',str(image),'--transition-type','fade','--transition-duration','0.6']
            ok, msg = run(argv)
        elif b == 'awww':
            ok, msg = run(['awww','img',str(image),'--transition-type','fade'])
        else:
            ok, msg = run(['hyprctl','hyprpaper','preload',str(image)]) if shutil.which('hyprctl') else (False,'hyprctl not found')
            if ok:
                ok, msg = run(['hyprctl','hyprpaper','wallpaper',f',{image}'])
        if ok:
            return emit(True, f'Wallpaper applied with {b}. Changes to Aether palette remain independent.', b)
        if backend != 'auto':
            return emit(False, msg or f'{b} is not running', b)
    return emit(False, 'No compatible running wallpaper daemon found. Install/start swww, awww or hyprpaper.')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('path')
    parser.add_argument('--backend', choices=['auto','swww','awww','hyprpaper'], default='auto')
    args = parser.parse_args()
    return apply(args.path, args.backend)

if __name__ == '__main__':
    sys.exit(main())
