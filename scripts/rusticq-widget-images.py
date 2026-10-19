#!/usr/bin/env python3
"""Choose one local image without following symlinks or loading image bytes.

Public protocol:  JSON {ok, uri, name, count} / {ok:false,message}.
No network, subprocess, thumbnail cache, recursive traversal or background service.
"""
import argparse
import json
import os
from pathlib import Path
import random
import sys

EXTENSIONS = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif'}
MAX_FILES = 1500


def choose(folder, previous=''):
    home = Path.home().resolve()
    source = (folder or '~/Pictures/Wallpapers').strip()
    if not source or '\x00' in source or len(source) > 1024:
        raise ValueError('Invalid image folder')
    raw = Path(os.path.expanduser(source))
    # Explicitly disallow any parent symlink and paths outside home.
    if not raw.is_absolute():
        raw = home / raw
    directory = raw.resolve(strict=True)
    if not directory.is_relative_to(home) or not directory.is_dir():
        raise ValueError('Image folder must be a directory inside your home')
    entries = []
    with os.scandir(directory) as iterator:
        for entry in iterator:
            if len(entries) >= MAX_FILES:
                break
            if entry.name.startswith('.') or entry.is_symlink() or not entry.is_file(follow_symlinks=False):
                continue
            if Path(entry.name).suffix.lower() not in EXTENSIONS:
                continue
            entries.append(entry.name)
    if not entries:
        return dict(ok=False, message='No local images found in this folder', count=0)
    pool = [name for name in entries if name != previous]
    name = random.choice(pool or entries)
    return dict(ok=True, uri=(directory / name).as_uri(), name=name, count=len(entries))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--folder', default='')
    parser.add_argument('--previous', default='')
    args = parser.parse_args()
    try:
        print(json.dumps(choose(args.folder, args.previous), ensure_ascii=False))
    except (ValueError, OSError) as error:
        print(json.dumps(dict(ok=False, message=str(error))))


if __name__ == '__main__':
    main()
