#!/usr/bin/env python3
"""Offline regression checks for RusticQ single-surface toast and sender actions."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
service = (root / 'services/NotificationCenter.qml').read_text()
toast = (root / 'modules/main/NotificationToasts.qml').read_text()
history = (root / 'modules/bar/BarNotifications.qml').read_text()
assert 'anchors.left: parent.left\n            anchors.top: parent.top\n            anchors.bottom: parent.bottom' not in toast, 'old left accent stripe still present'
assert 'id: bodyColumn' in toast and 'bodyColumn.implicitHeight' in toast, 'toast height should follow content'
assert 'implicitWidth: hasImage ?' in toast
assert 'Quickshell.iconPath' in toast, 'real app icons should be used when present'
assert 'source: toastWindow.hasImage ? notice.image : ""' in toast
assert 'NotificationCenter.invokeAction' in toast
assert 'NotificationCenter.invokeAction' in history
assert 'actionsSupported: true' in service
assert 'sourceIndex: i' in service, 'the original native action index must be preserved'
assert 'acts[index].invoke()' in service
assert 'textFormat: Text.PlainText' in toast
assert not re.search(r'\b(?:Open screenshot|Open folder|xdg-open|sh\s+-c)\b', toast), 'do not invent screenshot paths or commands'
from fontTools.ttLib import TTFont
font = TTFont(root / 'assets/google.ttf')
cmap = set().union(*(set(table.cmap) for table in font['cmap'].tables))
for code in re.findall(r'\\u([0-9A-Fa-f]{4})', toast):
    assert int(code, 16) in cmap, f'missing icon U+{code}'
print('PASS notification toast layout, real icons, screenshot thumbnail and safe native actions')
