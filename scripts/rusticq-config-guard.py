#!/usr/bin/env python3
"""Opt-in, local RusticQ JSON snapshots/recovery. No shell, sudo, or autostart edits.

Usage:
  python3 scripts/rusticq-config-guard.py status
  python3 scripts/rusticq-config-guard.py backup --kind settings
  python3 scripts/rusticq-config-guard.py list --kind settings
  python3 scripts/rusticq-config-guard.py restore --kind settings --id ID --confirm RESTORE
"""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat
import tempfile

KINDS = {'settings': 'user-settings.json', 'usage': 'app-usage.json'}
BACKUP_ID = re.compile(r'\A\d{8}T\d{6}Z-[0-9a-f]{12}\Z')
MAX_BYTES = 2_000_000


def validate_json(data):
    if not isinstance(data, (bytes, bytearray)) or len(data) > MAX_BYTES:
        raise ValueError('JSON exceeds 2 MB safety limit')
    obj = json.loads(data)
    if not isinstance(obj, dict):
        raise ValueError('Expected JSON object at file root')
    if any(not isinstance(k, str) or len(k) > 256 for k in obj):
        raise ValueError('Invalid JSON field names')
    return obj


def safe_read(path):
    if path.is_symlink():
        raise ValueError('Refusing symlink source: ' + str(path))
    if not path.is_file():
        raise ValueError('File is missing: ' + str(path))
    info = path.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_size > MAX_BYTES:
        raise ValueError('Not a supported regular JSON file')
    return path.read_bytes()


def atomic_write(path, data):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temp = None
    try:
        with tempfile.NamedTemporaryFile(prefix='.rusticq-', dir=path.parent, delete=False) as out:
            temp = Path(out.name)
            os.chmod(temp, 0o600)
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.replace(temp, path)
        temp = None
        fd = os.open(path.parent, os.O_RDONLY | getattr(os, 'O_DIRECTORY', 0))
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)


class Guard:
    def __init__(self, project, state):
        self.project = Path(project)
        self.state = Path(state) / 'rusticq' / 'config-backups'

    def source(self, kind):
        if kind not in KINDS:
            raise ValueError('Unknown config kind')
        return self.project / KINDS[kind]

    def target_dir(self, kind):
        return self.state / kind

    def snapshot(self, kind, allow_invalid=False):
        data = safe_read(self.source(kind))
        if not allow_invalid:
            validate_json(data)
        directory = self.target_dir(kind)
        directory.mkdir(parents=True, mode=0o700, exist_ok=True)
        stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        identifier = stamp + '-' + secrets.token_hex(6)
        target = directory / (identifier + '.json')
        # Exclusive create so a previous backup can never be overwritten.
        with target.open('xb') as out:
            os.chmod(target, 0o600)
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        return {'id': identifier, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}

    def versions(self, kind):
        folder = self.target_dir(kind)
        if not folder.is_dir():
            return []
        found = []
        for item in sorted(folder.iterdir(), reverse=True):
            if not BACKUP_ID.fullmatch(item.stem) or item.suffix != '.json':
                continue
            try:
                data = safe_read(item)
                validate_json(data)
            except (ValueError, OSError, json.JSONDecodeError):
                continue
            found.append({'id': item.stem, 'bytes': len(data),
                          'sha256': hashlib.sha256(data).hexdigest()})
        return found

    def status(self):
        result = {}
        for kind in KINDS:
            path = self.source(kind)
            try:
                validate_json(safe_read(path))
                state = 'valid'
            except (ValueError, OSError, json.JSONDecodeError):
                state = 'missing' if not path.exists() else 'invalid'
            result[kind] = {'status': state, 'snapshots': len(self.versions(kind))}
        return result

    def restore(self, kind, identifier, confirmation):
        if confirmation != 'RESTORE':
            raise ValueError('Restore requires exact confirmation RESTORE')
        if not BACKUP_ID.fullmatch(identifier):
            raise ValueError('Invalid snapshot identifier')
        candidate = self.target_dir(kind) / (identifier + '.json')
        original = safe_read(candidate)
        validate_json(original)
        current = self.source(kind)
        if current.is_symlink():
            raise ValueError('Refusing to replace symlink user configuration')
        # Preserve even an invalid current file for post-mortem recovery.
        if current.exists():
            self.snapshot(kind, allow_invalid=True)
        atomic_write(current, original)
        return {'restored': identifier, 'sha256': hashlib.sha256(original).hexdigest()}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=['status', 'backup', 'list', 'restore'])
    ap.add_argument('--kind', choices=list(KINDS), default='settings')
    ap.add_argument('--id', default='')
    ap.add_argument('--confirm', default='')
    args = ap.parse_args()
    home = Path.home()
    state = Path(os.environ.get('XDG_STATE_HOME', home / '.local/state'))
    guard = Guard(Path(__file__).resolve().parents[1], state)
    try:
        lockfile = state / 'rusticq/config-backups/.lock'
        lockfile.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        with lockfile.open('a+b') as lock:
            os.chmod(lockfile, 0o600)
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            actions = {
                'status': lambda: guard.status(),
                'backup': lambda: guard.snapshot(args.kind),
                'list': lambda: guard.versions(args.kind),
                'restore': lambda: guard.restore(args.kind, args.id, args.confirm)
            }
            print(json.dumps({'ok': True, 'data': actions[args.action]()}, ensure_ascii=False))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
