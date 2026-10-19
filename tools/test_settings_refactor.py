#!/usr/bin/env python3
"""Regression checks for the RC5 Settings/launcher refactor."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent

def source(path):
    p = ROOT / path
    assert p.is_file(), f"Missing: {p}"
    return p.read_text()

section = source('modules/settings/SettingsSection.qml')
assert 'implicitHeight: content.implicitHeight + 30' in section
assert 'default property alias controls: content.data' in section
win = source('modules/settings/SettingsWindow.qml')
assert 'contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + 16 : 0' in win
assert 'Loader {' in win
pages = ['appearance', 'bar', 'modules', 'widgets', 'dock', 'display', 'ai', 'about']
for p in pages:
    assert f'key:"{p}"' in win
    assert f'Store.settingsTab === "{p}"' in win or p == 'about'
for file in ['SettingsAppearancePage', 'SettingsBarPage', 'SettingsModulesPage', 'SettingsWidgetsPage',
             'SettingsDockPage', 'SettingsDisplaysPage', 'SettingsAIPage', 'SettingsAboutPage']:
    src=source(f'modules/settings/pages/{file}.qml')
    assert 'ColumnLayout {' in src and 'width: parent ? parent.width : 680' in src
bar=source('modules/settings/pages/SettingsBarPage.qml')
assert 'onCommit: next => SettingsStore.setBarMargin' in bar
assert all(k in bar for k in ('"clean-compact"', '"separated"', '"professional"', '"simple"'))
modules=source('modules/settings/pages/SettingsModulesPage.qml')
assert all(key in modules for key in ('showWifi','showBluetooth','showBattery','showAudio','showQuickModes','showLauncher'))
overlay=source('modules/main/LauncherOverlay.qml')
assert 'anchors.centerIn: parent' in overlay
assert 'Math.min(SettingsStore.launcherWidth,' in overlay  # configurable launcher width
assert 'Store.launcherVisible' in overlay
assert 'WlrLayer.Overlay' in overlay
launcher=source('modules/main/MiniLauncher.qml')
assert 'DesktopEntries.applications' in launcher and 'results = found' in launcher
assert 'onQueryChanged: rebuild()' in launcher
assert 'root.results' in launcher
shell=source('shell.qml')
assert 'LauncherOverlay { screen: Store.launcherScreen }' in shell
store=source('config/Store.qml')
assert 'function toggleLauncher(screen)' in store
assert 'Store.launcherVisible' not in source('modules/main/IndicatorPopup.qml')
assert 'width: ListView.view.width\n                height: Math.max(SettingsStore.launcherRowHeight, SettingsStore.launcherIconSize + 20)' in launcher
print('RC5 Settings refactor: page split, intrinsic sizing, launcher centering and persistence checks passed')
