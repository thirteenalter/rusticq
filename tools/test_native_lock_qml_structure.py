#!/usr/bin/env python3
"""Very lightweight static QML bracket scan, not a qmllint/runtime substitute."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
paths=sorted(root.rglob('*.qml'))
for path in paths:
    s=path.read_text(encoding='utf-8')
    depth=[]
    mode='code'; escape=False; i=0
    while i < len(s):
        ch=s[i]; nxt=s[i+1] if i+1<len(s) else ''
        if mode=='code':
            if ch=='/' and nxt=='/':mode='line';i+=1
            elif ch=='/' and nxt=='*':mode='comment';i+=1
            elif ch in ('"', "'", '`'):mode=ch
            elif ch in '{[(': depth.append(ch)
            elif ch in '}])':
                if not depth or depth.pop() != {'}':'{',']':'[',')':'('}[ch]:
                    raise AssertionError(f'Unbalanced QML: {path}')
        elif mode=='line':
            if ch=='\n':mode='code'
        elif mode=='comment':
            if ch=='*' and nxt=='/':mode='code';i+=1
        else:
            if escape:escape=False
            elif ch=='\\':escape=True
            elif ch==mode:mode='code'
        i+=1
    if depth or mode not in ('code','line'):
        raise AssertionError(f'Unclosed QML syntax: {path}')
print(f'Static bracket scan OK: {len(paths)} QML files')
