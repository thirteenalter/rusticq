#!/usr/bin/env python3
"""Deterministic RusticQ full/patch ZIP builder (source only).

Usage: python3 tools/build-release.py --out /tmp/dist --previous /path/previous-full.zip
No package installs, system changes, secrets, private config, or Git history.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {'.git','__pycache__','.pytest_cache','.venv','node_modules','.rusticq-patch-backup','dist'}
PRIVATE_NAMES = {'user-settings.json','app-usage.json','.env','.env.local'}
BINARY_FONTS = {'.ttf','.otf','.woff','.woff2'}
FIXED_EPOCH = (2026, 1, 1, 0, 0, 0)


def sources(root=ROOT):
    root = Path(root)
    entries = {}
    for p in sorted(root.rglob('*')):
        rel = p.relative_to(root)
        if any(part in SKIP_DIRS for part in rel.parts) or p.name in PRIVATE_NAMES:
            continue
        if p.is_symlink():
            raise ValueError('Refusing to package symlink: ' + str(rel))
        if not p.is_file() or p.suffix in BINARY_FONTS | {'.pyc','.key','.pem'}:
            continue
        if p.stat().st_size > 30_000_000:
            raise ValueError('Unusually large build file: ' + str(rel))
        entries['quickshell/'+rel.as_posix()] = p.read_bytes()
    return entries


def read_previous(path):
    with zipfile.ZipFile(path) as archive:
        result = {}
        for name in archive.namelist():
            if archive.getinfo(name).is_dir():
                continue
            if not name.startswith('quickshell/') or '..' in Path(name).parts:
                raise ValueError('Invalid previous archive path: ' + name)
            result[name] = archive.read(name)
        return result


def write_zip(target, entries):
    target.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zipf:
        for name, data in sorted(entries.items()):
            info = zipfile.ZipInfo(name, date_time=FIXED_EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if name.endswith(('.py','.sh')) else 0o644)) << 16
            zipf.writestr(info,data,compress_type=zipfile.ZIP_DEFLATED,compresslevel=9)
    with zipfile.ZipFile(target) as zipf:
        assert zipf.testzip() is None
    return hashlib.sha256(target.read_bytes()).hexdigest()


def build(out, previous=None, *, root=ROOT, label='rusticq-beta1-phase2'):
    full = sources(root)
    base = read_previous(previous) if previous is not None else {}
    removed = sorted(set(base) - set(full))
    if removed:
        raise ValueError('Patch cannot represent deleted paths: ' + ', '.join(removed[:10]))
    delta = {key:content for key,content in full.items() if base.get(key) != content}
    directory = Path(out)
    full_zip = directory/(label+'-full.zip')
    patch_zip = directory/(label+'-patch.zip')
    full_digest = write_zip(full_zip, full)
    patch_digest = write_zip(patch_zip, delta)
    manifest = {'label':label, 'full_sha256':full_digest,
                'patch_sha256':patch_digest,'full_count':len(full),
                'patch_count':len(delta),'patch_paths':sorted(delta),
                'previous_required':previous is not None,
                'note':'Patch overlays previous source; it does not delete files.'}
    (directory/(label+'-SHA256SUMS.txt')).write_text(f'{full_digest}  {full_zip.name}\n{patch_digest}  {patch_zip.name}\n')
    (directory/(label+'-manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n')
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',required=True,type=Path)
    parser.add_argument('--previous',type=Path)
    parser.add_argument('--label',default='rusticq-beta1-phase2')
    args=parser.parse_args()
    print(json.dumps(build(args.out,args.previous,label=args.label),indent=2))

if __name__ == '__main__':
    main()
