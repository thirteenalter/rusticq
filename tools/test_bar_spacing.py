#!/usr/bin/env python3
"""Regression checks for manual per-icon spacing in RusticQ Alpha 4."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
read = lambda p: (root / p).read_text()
store = read('config/SettingsStore.qml')
bar = read('modules/main/Bar.qml')
ind = read('components/Indicators.qml')
clock = read('components/Clock.qml')
rail = read('modules/main/VerticalBarContent.qml')
page = read('modules/settings/pages/SettingsBarPage.qml')
editor = read('modules/settings/pages/BarSpacingEditor.qml')
assert 'barSpacingOverrides: barSpacingOverrides' in store
assert 'barSpacingOverrides = validateSpacingOverrides(data.barSpacingOverrides)' in store
for fn in ['spacingGroup', 'spacingIcon', 'setGroupSpacing', 'setIconSpacing', 'resetSideSpacing', 'resetIconSpacing', 'validateSpacingOverrides']:
    assert 'function '+fn+'(' in store, fn
for group in ('left','right'):
    assert 'spacingGroup("'+group+'"' in bar
assert 'Layout.leftMargin: SettingsStore.spacingIcon("left", "arch", "before")' in bar
assert 'Layout.leftMargin: SettingsStore.spacingIcon("right", "weather", "before")' in bar
for key in ['bluetooth','wifi','battery','audio']:
    assert 'Layout.leftMargin: SettingsStore.spacingIcon("right", "'+key+'", "before")' in ind
assert 'visible: SettingsStore.showWifi && SettingsStore.showBattery' not in ind
assert 'useBarSpacing: true' in bar
for key in ['time','date']:
    assert 'SettingsStore.spacingIcon("right", "'+key+'", "before")' in clock
for key in ['arch','launcher','menu','workspaces','weather','time','date','bluetooth','wifi','battery','audio','task','quickControl']:
    assert 'SettingsStore.spacingIcon(' in rail
assert 'BarSpacingEditor { Layout.fillWidth: true }' in page
assert 'SettingsStore.setIconSpacing' in editor
assert 'SettingsStore.resetSideSpacing' in editor
assert 'onPreview: value => SettingsStore.setGroupSpacing' in editor
assert 'maximum: 16' in editor and 'maximum: 24' in editor
assert (root / 'changelog/ALPHA-4-SPACING-PATCH.md').exists()
print('Alpha 4 per-side per-icon spacing checks: PASS')
