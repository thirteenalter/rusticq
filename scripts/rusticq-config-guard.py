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
PORTABLE_FORMAT = 'rusticq-user-settings'
PORTABLE_VERSION = 1
MAX_BYTES = 2_000_000


def validate_json(data):
    if not isinstance(data, (bytes, bytearray)) or len(data) > MAX_BYTES:
        raise ValueError('JSON exceeds 2 MB safety limit')
    def reject_constant(value):
        raise ValueError('Invalid non-finite JSON number: ' + value)
    obj = json.loads(data, parse_constant=reject_constant)
    if not isinstance(obj, dict):
        raise ValueError('Expected JSON object at file root')
    stack = [(obj, 0)]
    seen = 0
    while stack:
        item, depth = stack.pop()
        seen += 1
        if depth > 25 or seen > 40000:
            raise ValueError('Settings JSON nesting or entry limit exceeded')
        if isinstance(item, dict):
            for key, value in item.items():
                if not isinstance(key, str) or len(key) > 256 or key in ('__proto__', 'prototype', 'constructor'):
                    raise ValueError('Invalid or unsafe settings JSON key')
                stack.append((value, depth + 1))
        elif isinstance(item, list):
            stack.extend((value, depth + 1) for value in item)
    return obj


def without_credentials(item):
    """Settings are transferable; credential fields (if added by plugins) aren't."""
    if isinstance(item, dict):
        return {key: without_credentials(value) for key, value in item.items()
                if not any(word in key.lower().replace('_', '').replace('-', '')
                           for word in ('apikey', 'password', 'secret', 'credential', 'token'))}
    if isinstance(item, list):
        return [without_credentials(value) for value in item]
    return item


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

    def portable_export(self):
        """Export the current settings as a portable JSON file, not an Omarchy restore."""
        settings = without_credentials(validate_json(safe_read(self.source('settings'))))
        target_dir = Path.home() / 'Documents' / 'RusticQ-Settings'
        if target_dir.is_symlink() or (target_dir.exists() and not target_dir.is_dir()):
            raise ValueError('Unsafe export directory: ' + str(target_dir))
        target_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        target_dir.chmod(0o700)
        stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        filename = f'rusticq-settings-{stamp}-{secrets.token_hex(4)}.json'
        destination = target_dir / filename
        # No API-key database, AI-keyring entry, usage statistics, or backups.
        package = dict(format=PORTABLE_FORMAT, version=PORTABLE_VERSION,
                       exported_utc=dt.datetime.now(dt.timezone.utc).isoformat(),
                       settings=settings)
        payload = (json.dumps(package, ensure_ascii=False, indent=2, sort_keys=True) + '\n').encode('utf-8')
        if len(payload) > MAX_BYTES:
            raise ValueError('Portable settings exceed 2 MB safety limit')
        with destination.open('xb') as out:
            os.chmod(destination, 0o600)
            out.write(payload)
            out.flush()
            os.fsync(out.fileno())
        return dict(path=str(destination), sha256=hashlib.sha256(payload).hexdigest(),
                    fields=len(settings), bytes=len(payload),
                    message='Settings saved as a portable JSON file. Store it privately: it may contain local paths and notes.')

    def _portable_source(self, user_path):
        if not isinstance(user_path, str) or not user_path.strip():
            raise ValueError('Choose a JSON file to load first')
        source = Path(os.path.expanduser(user_path.strip()))
        if source.suffix.lower() != '.json':
            raise ValueError('Select a .json settings file')
        blob = safe_read(source)
        object_value = validate_json(blob)
        if object_value.get('format') == PORTABLE_FORMAT:
            if object_value.get('version') != PORTABLE_VERSION:
                raise ValueError('Unsupported portable settings version')
            settings = object_value.get('settings')
            if not isinstance(settings, dict):
                raise ValueError('Portable file has no settings object')
            # Also checks the extracted JSON size and property names.
            source_type = 'RusticQ portable export'
        elif 'format' in object_value or 'version' in object_value and 'settings' in object_value:
            raise ValueError('Unrecognized portable settings format')
        else:
            settings = object_value  # legacy plain user-settings.json
            source_type = 'Legacy user-settings.json'
        converted = (json.dumps(settings, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
        validate_json(converted)
        return source, converted, settings, source_type

    def portable_inspect(self, user_path):
        source, converted, settings, source_type = self._portable_source(user_path)
        return dict(path=str(source), format=source_type, fields=len(settings),
                    bytes=len(converted), sha256=hashlib.sha256(converted).hexdigest(),
                    wallpaper=settings.get('wallpaperBackend', ''),
                    bar=settings.get('barMode', ''),
                    message='File valid. Import will replace user-settings.json after a verified safety snapshot. Restart RusticQ afterward.')

    def portable_import(self, user_path, confirmation, expected_sha256=''):
        if confirmation != 'IMPORT SETTINGS':
            raise ValueError('Import requires exact confirmation IMPORT SETTINGS')
        source, converted, settings, source_type = self._portable_source(user_path)
        checksum = hashlib.sha256(converted).hexdigest()
        if not re.fullmatch(r'[0-9a-f]{64}', expected_sha256) or expected_sha256 != checksum:
            raise ValueError('The selected file changed since preview. Inspect it again before importing.')
        destination = self.source('settings')
        if destination.is_symlink():
            raise ValueError('Refusing symlink settings destination')
        # Never overwrite current configuration before safeguarding the original.
        snapshot = self.snapshot('settings', allow_invalid=True) if destination.exists() else None
        atomic_write(destination, converted)
        # Verify on-disk copy and keep old snapshot even if a later error occurs.
        if hashlib.sha256(safe_read(destination)).hexdigest() != checksum:
            raise ValueError('Imported config could not be verified. Recover from the saved snapshot.')
        return dict(path=str(destination), source=str(source), sha256=checksum,
                    backup_id=snapshot['id'] if snapshot else None, fields=len(settings),
                    message='User settings imported and verified. Restart the active RusticQ instance to load the new settings. Current settings were backed up first.')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('action', choices=['status', 'backup', 'list', 'restore', 'export', 'inspect', 'import'])
    ap.add_argument('--kind', choices=list(KINDS), default='settings')
    ap.add_argument('--id', default='')
    ap.add_argument('--confirm', default='')
    ap.add_argument('--path', default='')
    ap.add_argument('--sha256', default='')
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
                'restore': lambda: guard.restore(args.kind, args.id, args.confirm),
                'export': guard.portable_export,
                'inspect': lambda: guard.portable_inspect(args.path),
                'import': lambda: guard.portable_import(args.path, args.confirm, args.sha256)
            }
            print(json.dumps({'ok': True, 'data': actions[args.action]()}, ensure_ascii=False))
    except (OSError, ValueError, json.JSONDecodeError, RecursionError, UnicodeError) as exc:
        print(json.dumps({'ok': False, 'error': str(exc)}, ensure_ascii=False))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
