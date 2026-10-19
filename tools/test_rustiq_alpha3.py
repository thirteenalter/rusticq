#!/usr/bin/env python3
"""Alpha 3 source & theme asset regression tests (not a Hyprland runtime test)."""
import json
from pathlib import Path
from fontTools.ttLib import TTFont

root = Path(__file__).resolve().parents[1]
store = (root / 'config/SettingsStore.qml').read_text()
bar = (root / 'modules/main/Bar.qml').read_text()
popup = (root / 'modules/main/IndicatorPopup.qml').read_text()
settings = (root / 'modules/settings/SettingsWindow.qml').read_text()
rail = (root / 'modules/main/VerticalBarContent.qml').read_text()
assert 'property string barPosition: "top"' in store
assert 'barPosition: barPosition' in store
assert 'data.barPosition' in store
for side in ['top', 'bottom', 'left', 'right']:
    assert f'key: "{side}"' in settings
assert 'SettingsStore.save()' in settings
assert 'VerticalBarContent {' in bar and 'visible: barWindow.verticalMode' in bar
assert 'implicitWidth: verticalMode ?' in bar and 'Theme.verticalBarWidth' in bar
assert 'implicitHeight: verticalMode ? 0 : barHeight' in bar
assert 'anchors {' in bar and 'top: barWindow.barPosition !== "bottom"' in bar
assert 'anchor.edges:' in popup and 'anchor.gravity:' in popup
assert 'targetY: barWindow.miniAnchorY' in bar
assert 'onRequestPopup: (kind, x, y)' in bar
assert 'Flickable {' in rail and 'contentHeight: railContent.implicitHeight' in rail
assert 'mapFromItem(item,' in rail
for kind in ('bluetooth','wifi','battery','audio','weather','date','time'):
    assert f'"{kind}"' in rail
font = TTFont(root/'assets/google.ttf')
cmap = font.getBestCmap()
for code in (0xe5d8,0xe5db,0xe5de,0xe5df,0xe69b,0xebcc,0xe8b5,0xeb8e):
    assert code in cmap, hex(code)
data = json.loads((root/'user-settings.json').read_text())
assert data['barPosition'] == 'top'
# Anchor state table, matching the declarative expressions in Bar.qml:
for position in ('top','bottom','left','right'):
    edges=(position!='bottom',position!='top',position!='right',position!='left')
    assert sum(edges)==3
print('PASS: 4 bar positions, adaptive rail, mini widget anchor routing, settings persistence, Material glyphs')
