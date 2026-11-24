#!/usr/bin/env python3
"""Read local RusticQ release manifests without network requests or state writes."""
import argparse
from datetime import date
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TAG = re.compile(r'(?P<legacy>rustiq-)?(?P<channel>alpha|beta)-(?P<number>[1-9]\d*)(?:-rc-?(?P<candidate>[1-9]\d*))?')


def read_tag(root=ROOT):
    path = Path(root) / 'VERSION'
    if path.is_symlink():
        raise ValueError('VERSION must be a regular file')
    tag = path.read_text(encoding='utf-8').strip()
    if not TAG.fullmatch(tag):
        raise ValueError('Invalid local release tag in VERSION')
    return tag


def load_manifest(root, tag):
    match = TAG.fullmatch(tag)
    if not match:
        raise ValueError('Invalid release tag')
    relative = Path('config/releases') / (tag + '.json')
    path = Path(root) / relative
    if path.is_symlink():
        raise ValueError('Release manifest must be a regular file: ' + str(relative))
    data = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(data, dict) or type(data.get('schemaVersion')) is not int or data['schemaVersion'] != 1:
        raise ValueError('Unsupported release manifest schema: ' + str(relative))
    if data.get('tag') != tag:
        raise ValueError('Release manifest tag does not match its filename: ' + str(relative))
    channel = match['channel']
    number = int(match['number'])
    candidate = int(match['candidate']) if match['candidate'] else None
    name = channel.title() + ' ' + str(number) + (' RC' + str(candidate) if candidate else '')
    if data.get('name') != name:
        raise ValueError('Release name does not match its tag: ' + str(relative))
    if not isinstance(data.get('minimumQuickshell'), str) or not re.fullmatch(r'\d+\.\d+\.\d+', data['minimumQuickshell']):
        raise ValueError('Invalid Quickshell minimum: ' + str(relative))
    if not isinstance(data.get('summary'), str) or not data['summary'].strip():
        raise ValueError('Release summary is missing: ' + str(relative))
    released = data.get('date')
    if released is not None:
        if not isinstance(released, str) or date.fromisoformat(released).isoformat() != released:
            raise ValueError('Invalid release date: ' + str(relative))
    for key in ('changes', 'notes'):
        values = data.get(key)
        if not isinstance(values, list) or not values or any(not isinstance(value, str) or not value.strip() for value in values):
            raise ValueError('Release ' + key + ' must be a nonempty list of text: ' + str(relative))
    for note in data['notes']:
        note_path = Path(note)
        if note_path.is_absolute() or '..' in note_path.parts or not note.startswith(('changelog/', 'docs/')):
            raise ValueError('Invalid release note path: ' + str(relative))
        if not (Path(root) / note_path).is_file():
            raise ValueError('Missing release notes: ' + note)
    return dict(data, channel=channel, number=number, candidate=candidate, manifest=relative.as_posix())


def current_release(root=ROOT):
    return load_manifest(root, read_tag(root))


def release_catalog(root=ROOT):
    current = current_release(root)
    releases = [current]
    warnings = []
    for path in sorted((Path(root) / 'config/releases').glob('*.json')):
        if path.stem == current['tag']:
            continue
        try:
            releases.append(load_manifest(root, path.stem))
        except (OSError, ValueError) as exc:
            warnings.append('Unable to load ' + path.name + ': ' + str(exc))
    releases.sort(key=lambda release: (release['channel'] == 'beta', release['number'],
                                      release['candidate'] is None, release['candidate'] or 0), reverse=True)
    return dict(current=current, releases=releases, warnings=warnings)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('current', 'catalog'), nargs='?', default='current')
    args = parser.parse_args(argv)
    try:
        result = current_release() if args.action == 'current' else release_catalog()
        payload = dict(ok=True, result=result)
        code = 0
    except (OSError, ValueError) as exc:
        payload = dict(ok=False, error='Unable to read local release metadata: ' + str(exc))
        code = 1
    print(json.dumps(payload, ensure_ascii=False))
    return code


if __name__ == '__main__':
    raise SystemExit(main())
