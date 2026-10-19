#!/usr/bin/env python3
"""Unified spacing regression for Alpha 4 RC2 (the old direct-Bar layout is retired)."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
read=lambda rel:(root/rel).read_text(encoding='utf-8')
store=read('config/SettingsStore.qml')
bar=read('modules/main/Bar.qml')
zone=read('components/BarZone.qml')
rail=read('modules/main/VerticalBarContent.qml')
page=read('modules/settings/pages/SettingsBarPage.qml')
editor=read('modules/settings/pages/BarSpacingEditor.qml')
assert 'barSpacingOverrides: barSpacingOverrides' in store
assert 'barSpacingOverrides = validateSpacingOverrides(data.barSpacingOverrides)' in store
for fn in ['spacingGroup','spacingIcon','setGroupSpacing','setIconSpacing','resetSideSpacing','resetIconSpacing','validateSpacingOverrides','transferIconSpacing']:
    assert 'function '+fn+'(' in store, fn
for side in ['left','center','right']:
    assert 'zone: "'+side+'"' in bar or 'zone: "'+side+'"' in rail
    assert side in editor
assert 'Layout.leftMargin: SettingsStore.spacingIcon(root.zone, modelData, "before")' in zone
assert 'Layout.rightMargin: SettingsStore.spacingIcon(root.zone, modelData, "after")' in zone
assert 'Layout.topMargin: SettingsStore.spacingIcon(root.zone, modelData, "before")' in zone
assert 'Layout.bottomMargin: SettingsStore.spacingIcon(root.zone, modelData, "after")' in zone
assert 'SettingsStore.placementFor(item.key) === side' in editor
assert 'BarSpacingEditor { Layout.fillWidth: true }' in page
assert 'onPreview: value => SettingsStore.setGroupSpacing' in editor
assert 'maximum: 16' in editor and 'maximum: 24' in editor
assert 'onChoicesChanged' in editor
assert (root/'changelog/ALPHA-4-RC2-UNIFIED-ICON-ALIGNMENT-SPACING-FIX.md').exists()
print('Alpha 4 all-zone per-icon spacing checks: PASS')
