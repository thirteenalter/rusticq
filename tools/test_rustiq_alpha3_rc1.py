#!/usr/bin/env python3
"""Static RC1 regression. This is NOT a test in a running Hyprland session."""
from pathlib import Path
from fontTools.ttLib import TTFont
import json, re, subprocess, os, tempfile
root=Path(__file__).resolve().parents[1]
def source(name): return (root/name).read_text()
bar=source('modules/main/Bar.qml')
rail=source('modules/main/VerticalBarContent.qml')
settings=source('modules/settings/SettingsWindow.qml')
store=source('config/SettingsStore.qml')
popup=source('modules/main/IndicatorPopup.qml')
menu=source('modules/main/ContextMenu.qml')
menuBar=source('components/ContextMenuBar.qml')
assert 'readonly property int barHeight: professionalMode ? 44 : separatedMode ? 40 : compactMode ? 36 : 38' in bar
assert 'anchors.leftMargin: barWindow.professionalMode ? 17 : 0' in bar
assert 'readonly property int barEdgeGap: 4' in source('config/Theme.qml')
assert 'Layout.fillWidth: true' in bar and 'RUSTICQ  /  GRUVBOX' in bar
assert 'property bool showMenuBar: false' in store
assert 'showMenuBar: showMenuBar' in store and 'data.showMenuBar' in store
assert json.loads(source('user-settings.json'))['showMenuBar'] is False
assert 'key: "showMenuBar"' in settings
assert 'Side bars reorganize controls vertically' in settings
for mode in ['compact', 'clean-compact', 'separated', 'professional', 'simple']:
    assert ('mode === "' + mode + '"') in rail or (mode=='separated' and 'mode === "separated"' in rail)
    assert ('"' + mode + '"') in menu
assert 'implicitWidth: verticalMode ? (simpleMode ? 48' in bar
assert 'signal requestMenu(' in rail and 'onRequestMenu:' in bar
assert 'SettingsStore.showMenuBar && barWindow.width > 980' in bar
assert 'onMenuRequested:' in bar
for label in ['Edit', 'View', 'Share']: assert label in menuBar
assert 'currentSection' in menu and 'onSectionChanged:' in menu
assert 'Qt.resolvedUrl("../../scripts/rustiq-capture.sh")' in menu
assert 'singleSystem ? 0 : 1' in popup
assert 'singleSystem ? 0 : 8' in popup
for kind in ['wifi','bluetooth','battery']:
    assert 'kind === "' + kind + '"' in popup
cmap=TTFont(root/'assets/google.ttf').getBestCmap()
for name in ['modules/main/ContextMenu.qml','components/ContextMenuBar.qml','modules/main/VerticalBarContent.qml']:
    glyphs={int(c,16) for c in re.findall(r'\\u([0-9a-fA-F]{4})',source(name))}
    assert glyphs <= set(cmap), (name,glyphs-set(cmap))
# Reject arbitrary action arguments to the optional screenshot helper.
proc=subprocess.run(['sh', str(root/'scripts/rustiq-capture.sh'), 'malicious-input'],capture_output=True)
assert proc.returncode==2
# Offline screenshot mock demonstrates destination and shell argument handling.
with tempfile.TemporaryDirectory() as t:
    tmp=Path(t); binpath=tmp/'bin'; binpath.mkdir(); pic=tmp/'Pictures'
    shim=binpath/'grim'; shim.write_text('#!/bin/sh\nprintf "%s\\n" "$@" >> "$MOCK_LOG"\ntouch "$1"\n'); shim.chmod(0o755)
    env=dict(os.environ,PATH=str(binpath)+':'+os.environ['PATH'],XDG_PICTURES_DIR=str(pic),MOCK_LOG=str(tmp/'log'))
    result=subprocess.run(['sh', str(root/'scripts/rustiq-capture.sh'), 'full'], env=env, capture_output=True)
    assert result.returncode==0, result.stderr
    assert list((pic/'Screenshots').glob('rustiq-*.png'))
print('PASS: RC1 margins, 5 side modes, optional menu, popup borders, glyphs and local screenshot helper')
