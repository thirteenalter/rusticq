#!/usr/bin/env python3
"""On-demand constrained file/window/workspace providers for RusticQ's existing launcher.

Search never runs without an explicit :files/:folders/:windows/:workspaces query.
Never search .ssh, .gnupg, browser profiles, hidden directories or network mounts.
Hyprland focus actions use an exact live address/id from a re-queried snapshot.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

MAX_RESULTS = 40
MAX_VISITED = 1800
MAX_SIZE = 250 * 1024 * 1024
SEARCH_DIRS = ('Documents', 'Downloads', 'Desktop', 'Pictures', 'Music', 'Videos')


def file_results(text, *, folders=False, home=None):
    home = (Path.home() if home is None else Path(home)).resolve()
    matches = []
    seen = set()
    examined = 0
    q = text.casefold().strip()
    if not q:
        return []  # Avoid enumerating private files on empty query.
    for dirname in SEARCH_DIRS:
        base = home / dirname
        if not base.is_dir() or base.is_symlink():
            continue
        for root, dirs, files in os.walk(base, followlinks=False):
            location = Path(root)
            depth = len(location.relative_to(base).parts)
            dirs[:] = sorted(d for d in dirs if depth < 4 and not d.startswith('.') and not (location / d).is_symlink())[:60]
            names = dirs if folders else files
            for name in names:
                examined += 1
                if examined > MAX_VISITED:
                    return matches[:MAX_RESULTS]
                if name.startswith('.') or q not in name.casefold():
                    continue
                target = location / name
                if target.is_symlink():
                    continue
                try:
                    resolved = target.resolve(strict=True)
                    resolved.relative_to(home)
                    if folders and not resolved.is_dir():
                        continue
                    if not folders and (not resolved.is_file() or resolved.stat().st_size > MAX_SIZE):
                        continue
                except (OSError, ValueError):
                    continue
                if resolved in seen:
                    continue
                seen.add(resolved)
                matches.append({'label': name, 'detail': str(resolved.relative_to(home)),
                                'action': 'folder' if folders else 'file', 'payload': str(resolved),
                                'icon': '📂' if folders else '📄'})
                if len(matches) >= MAX_RESULTS:
                    return matches
    return matches


def hypr_snapshot(what):
    if shutil.which('hyprctl') is None:
        raise RuntimeError('Hyprland IPC is not available')
    result = subprocess.run(['hyprctl', '-j', what], capture_output=True, text=True, timeout=4, check=False)
    if result.returncode != 0:
        raise RuntimeError('Unable to query Hyprland ' + what)
    data = json.loads(result.stdout)
    if not isinstance(data, list):
        raise RuntimeError('Unexpected compositor response')
    return data


def search_hypr(what, text):
    data = hypr_snapshot('clients' if what == 'windows' else 'workspaces')
    result = []
    q = text.casefold()
    for entry in data[:250]:
        if not isinstance(entry, dict):
            continue
        if what == 'windows':
            address = entry.get('address', '')
            if not isinstance(address, str) or not re.fullmatch(r'0x[0-9a-fA-F]{4,16}', address):
                continue
            title = str(entry.get('title') or entry.get('class') or 'Untitled')[:160]
            detail = str(entry.get('class') or '')[:80]
            if q not in (title + ' ' + detail).casefold():
                continue
            result.append(dict(label=title, detail=detail, action='window', payload=address, icon='▣'))
        else:
            wid = entry.get('id')
            if type(wid) is not int or wid <= 0 or wid > 10000:
                continue
            label = 'Workspace ' + str(wid)
            if q not in (label + ' ' + str(entry.get('name') or '')).casefold():
                continue
            result.append(dict(label=label, detail=str(entry.get('windows', 0)) + ' windows',
                               action='workspace', payload=str(wid), icon='▦'))
        if len(result) >= MAX_RESULTS:
            break
    return result


def open_item(action, payload, *, home=None):
    if action in ('file', 'folder'):
        home = (Path.home() if home is None else Path(home)).resolve()
        target = Path(payload)
        if not target.is_absolute() or target.is_symlink():
            raise ValueError('Unsafe path')
        resolved = target.resolve(strict=True)
        try:
            resolved.relative_to(home)
        except ValueError as exc:
            raise ValueError('Path outside home') from exc
        if not any(resolved.is_relative_to(home / part) for part in SEARCH_DIRS):
            raise ValueError('Path is not within allowed personal directories')
        if action == 'file' and (not resolved.is_file() or resolved.stat().st_size > MAX_SIZE):
            raise ValueError('File missing or too large')
        if action == 'folder' and not resolved.is_dir():
            raise ValueError('Folder missing')
        if not shutil.which('xdg-open'):
            raise RuntimeError('Install xdg-utils for file opening')
        subprocess.Popen(['xdg-open', str(resolved)], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, start_new_session=True)
        return 'Opening ' + resolved.name
    if action == 'window':
        if not re.fullmatch(r'0x[0-9a-fA-F]{4,16}', payload):
            raise ValueError('Invalid Hyprland window address')
        if not any(e.get('address') == payload for e in hypr_snapshot('clients')):
            raise ValueError('Window no longer exists')
        cmd = ['hyprctl', 'dispatch', 'focuswindow', 'address:' + payload]
    elif action == 'workspace':
        if not re.fullmatch(r'[1-9][0-9]{0,4}', payload):
            raise ValueError('Invalid workspace')
        if not any(e.get('id') == int(payload) for e in hypr_snapshot('workspaces')):
            raise ValueError('Workspace no longer exists')
        cmd = ['hyprctl', 'dispatch', 'workspace', payload]
    else:
        raise ValueError('Unsupported desktop provider action')
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=4, check=False)
    if result.returncode or any(token in (result.stdout + result.stderr).lower() for token in ('error', 'invalid', 'unknown')):
        raise RuntimeError('Compositor rejected focus request')
    return 'Focused ' + action
