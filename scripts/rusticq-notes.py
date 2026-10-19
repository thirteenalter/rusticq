#!/usr/bin/env python3
"""RusticQ local notes / three-stage Kanban.

Private, bounded, atomic JSON state. No network, shell eval, or always-on service.
CLI: list [query] | add TITLE | move ID STAGE | delete ID | toggle ID
"""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import uuid
from contextlib import contextmanager

STATE = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'rusticq' / 'notes.json'
STAGES = ('todo', 'doing', 'done')
MAX_NOTES = 250
MAX_TITLE = 260


def validate_title(title):
    if not isinstance(title, str) or not title.strip() or len(title) > MAX_TITLE or any(ord(ch) < 32 and ch != '\t' for ch in title):
        raise ValueError('Note must be 1-260 printable characters')
    return title.strip()


def validate_db(db):
    if not isinstance(db, dict) or db.get('schema') != 1 or not isinstance(db.get('notes'), list) or len(db['notes']) > MAX_NOTES:
        raise ValueError('Notes database has invalid schema or exceeds limits')
    ids = set()
    for n in db['notes']:
        if not isinstance(n, dict) or not re.fullmatch(r'[0-9a-f]{32}', str(n.get('id', ''))) or n['id'] in ids or n.get('stage') not in STAGES:
            raise ValueError('Invalid note entry')
        validate_title(n.get('title'))
        ids.add(n['id'])
    return db


def read_db():
    if not STATE.exists():
        return {'schema': 1, 'notes': []}
    if STATE.is_symlink() or STATE.stat().st_size > 250_000:
        raise ValueError('Unsafe or oversized notes file')
    return validate_db(json.loads(STATE.read_text(encoding='utf-8')))


def write_db(db):
    validate_db(db)
    STATE.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    encoded = json.dumps(db, ensure_ascii=False, indent=2).encode('utf-8')
    fd, tmp = tempfile.mkstemp(dir=STATE.parent, prefix='.notes-', suffix='.tmp')
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(tmp, STATE)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


@contextmanager
def lock():
    STATE.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE.parent / 'notes.lock').open('a+') as file:
        os.chmod(file.name, 0o600)
        fcntl.flock(file.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(file.fileno(), fcntl.LOCK_UN)


def op(action, *args):
    if action == 'list':
        query = (args[0] if args else '').casefold()
        db = read_db()
        return {'items': [note for note in db['notes'] if query in note['title'].casefold() or query in note['stage']][:80]}
    with lock():
        db = read_db()
        if action == 'add':
            title = validate_title(args[0])
            if len(db['notes']) >= MAX_NOTES:
                raise ValueError('Maximum 250 notes reached')
            note = {'id': uuid.uuid4().hex, 'title': title, 'stage': 'todo'}
            db['notes'].insert(0, note)
            result = note
        else:
            note_id = args[0]
            if not re.fullmatch(r'[0-9a-f]{32}', note_id):
                raise ValueError('Invalid note ID')
            note = next((n for n in db['notes'] if n['id'] == note_id), None)
            if note is None:
                raise ValueError('Note not found')
            if action == 'move':
                stage = args[1]
                if stage not in STAGES:
                    raise ValueError('Unknown Kanban column')
                note['stage'] = stage
            elif action == 'toggle':
                note['stage'] = STAGES[(STAGES.index(note['stage']) + 1) % 3]
            elif action == 'delete':
                db['notes'].remove(note)
            else:
                raise ValueError('Unsupported notes operation')
            result = note
        write_db(db)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['list', 'add', 'move', 'toggle', 'delete'])
    parser.add_argument('value', nargs='?', default='')
    parser.add_argument('stage', nargs='?', default='')
    args = parser.parse_args(argv)
    try:
        result = op(args.action, args.value, args.stage)
        print(json.dumps({'ok': True, 'result': result}, ensure_ascii=False))
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print(json.dumps({'ok': False, 'message': str(exc)}, ensure_ascii=False))
        return 1


if __name__ == '__main__':
    sys.exit(main())
