#!/usr/bin/env python3
"""Lightweight QML structural validation. Does not replace running `qs`."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
paths = sorted(root.rglob('*.qml'))
problems = []
for path in paths:
    source = path.read_text(encoding='utf-8')
    stack = []
    state = 'code'
    i = 0
    line = 1
    while i < len(source):
        ch = source[i]
        nxt = source[i+1] if i+1 < len(source) else ''
        if ch == '\n':
            line += 1
        if state == 'code':
            if ch == '/' and nxt == '/':
                state = 'line'
                i += 1
            elif ch == '/' and nxt == '*':
                state = 'block'
                i += 1
            elif ch in '"\'`':
                state = ch
            elif ch in '([{':
                stack.append((ch, line))
            elif ch in ')]}':
                if not stack or '([{'.index(stack[-1][0]) != ')]}'.index(ch):
                    problems.append(f'{path.relative_to(root)}:{line}: unexpected {ch}')
                else:
                    stack.pop()
        elif state == 'line':
            if ch == '\n':
                state = 'code'
        elif state == 'block':
            if ch == '*' and nxt == '/':
                state = 'code'
                i += 1
        else:
            if ch == '\\':
                i += 1
            elif ch == state:
                state = 'code'
        i += 1
    # QML component declarations are adjacent objects, not JS statements.
    # `Icon { ... }; Text { ... }` is a syntax error even with balanced braces.
    # Keep strings/comments blanked to avoid matching incidental source text.
    masked = []
    state2 = 'code'
    cursor = 0
    while cursor < len(source):
        ch = source[cursor]
        nxt = source[cursor+1] if cursor+1 < len(source) else ''
        if state2 == 'code':
            if ch == '/' and nxt == '/':
                state2 = 'line'
                masked.extend([' ', ' ']); cursor += 2; continue
            if ch == '/' and nxt == '*':
                state2 = 'block'
                masked.extend([' ', ' ']); cursor += 2; continue
            if ch in ('"', "'", '`'):
                state2 = ch
                masked.append(' '); cursor += 1; continue
            masked.append(ch)
        elif state2 == 'line':
            if ch == '\n':
                state2 = 'code'
                masked.append('\n')
            else:
                masked.append(' ')
        elif state2 == 'block':
            if ch == '*' and nxt == '/':
                masked.extend([' ', ' ']); cursor += 2
                state2 = 'code'; continue
            masked.append('\n' if ch == '\n' else ' ')
        else:
            if ch == '\\':
                masked.extend([' ', ' ']); cursor += 2; continue
            if ch == state2:
                state2 = 'code'
            masked.append('\n' if ch == '\n' else ' ')
        cursor += 1
    stripped = ''.join(masked)
    for match in re.finditer(r'\}\s*;\s*(?=[A-Z][A-Za-z0-9_.]*\s*\{)', stripped):
        lineno = stripped.count('\n', 0, match.start()) + 1
        problems.append(f'{path.relative_to(root)}:{lineno}: invalid semicolon between QML object declarations')

    if stack:
        problems.append(f'{path.relative_to(root)}: unclosed {stack[-3:]}')
    if state in ['"', "'", '`', 'block']:
        problems.append(f'{path.relative_to(root)}: unterminated {state}')
    for relative in re.findall(r'^\s*import\s+"([^"\n]+)"', source, re.M):
        if not (path.parent / relative).is_dir():
            problems.append(f'{path.relative_to(root)}: missing import {relative}')
for dirname in ('services', 'config'):
    for declaration in (root / dirname / 'qmldir').read_text(encoding='utf-8').splitlines():
        words = declaration.split()
        if not words:
            continue
        filename = words[3] if words[0] == 'singleton' else words[2] if len(words) > 2 else None
        if filename and not (root / dirname / filename).is_file():
            problems.append(f'{dirname}/qmldir: {filename} missing')

# Interaction checks: explicit header hitboxes and local dropdown state.
header = (root / 'components' / 'SectionHeader.qml').read_text(encoding='utf-8')
if 'height: 36' not in header or 'onClicked: root.toggleRequested()' not in header:
    problems.append('SectionHeader missing real clickable height')
for widget, target in [('BarWifi', 'wifiWidget'), ('BarBluetooth', 'root'), ('BarBattery', 'root')]:
    source = (root / 'modules' / 'bar' / f'{widget}.qml').read_text(encoding='utf-8')
    if f'onToggleRequested: if (!{target}.standalone) {target}.expanded = !{target}.expanded' not in source:
        problems.append(f'{widget}: accordion must toggle locally except in mini mode')
    if 'readonly property bool contentOpen: standalone || expanded' not in source:
        problems.append(f'{widget}: standalone must force the content open')
source = (root / 'modules' / 'bar' / 'BarSystem.qml').read_text(encoding='utf-8')
if 'visible: root.expanded' in source or 'Store.toggleQuickSection' in source:
    problems.append('System panel should be permanently expanded')
pill = (root / 'components' / 'Pill.qml').read_text(encoding='utf-8')
if 'childrenRect' in '\n'.join(line for line in pill.splitlines() if not line.strip().startswith('//')):
    problems.append('Pill sizing reintroduced childrenRect loop')

print(f'Static checks: {len(paths)} QML files, {len(problems)} issues')
for message in problems:
    print('FAIL:', message)
sys.exit(bool(problems))
