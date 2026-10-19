#!/usr/bin/env python3
"""Source-level regression guard for Alpha 4. Run: python3 tools/test_alpha4.py"""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]

def source(name):
    return (root / name).read_text(encoding='utf8')

settings = source('config/SettingsStore.qml')
assert 'property bool dockRunningApps: false' in settings
assert 'function moveQuickCard' in settings
assert 'function resetQuickOrder' in settings
assert 'quickControlOrder: quickControlOrder' in settings
assert 'dockRunningApps: dockRunningApps' in settings
assert 'validQuickOrder(data.quickControlOrder)' in settings
assert 'quickReorderMode' in source('config/Store.qml')
assert 'onReleased:' in source('modules/bar/BarMain.qml')
assert 'SettingsStore.moveQuickCard' in source('modules/bar/BarMain.qml')
assert 'SectionHeader {' in source('modules/bar/BarNotifications.qml')
assert 'Hyprland.toplevels.values' in source('modules/main/RusticDock.qml')
assert 'modelData.activate()' in source('modules/main/RusticDock.qml')
assert 'SettingsStore.dockRunningApps' in source('modules/main/RusticDock.qml')
assert 'dockRunningApps' in source('modules/settings/pages/SettingsDockPage.qml')
assert 'visible: SettingsStore.showWifi && SettingsStore.showBattery' not in source('components/Indicators.qml')  # duplicate fixed spacer removed
assert 'id: launcherCard' not in source('modules/main/LauncherOverlay.qml')
assert 'color: Theme.background' in source('modules/main/MiniLauncher.qml')
assert 'Alpha 4' in source('README.md')
assert len(list((root / 'changelog').glob('*.md'))) >= 15
assert not list(root.glob('HOTFIX*.md'))
assert not list(root.glob('RUSTIQ-*.md'))
print('Alpha 4 source regression: PASS')
