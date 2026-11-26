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
assert 'Suite.SettingsGroup {' in section
group=source('components/settings/SettingsGroup.qml')
assert 'implicitHeight:content.implicitHeight+Theme.sectionPadding*2' in group
assert 'default property alias controls: content.data' in group
win = source('modules/settings/SettingsWindow.qml')
frame=source('components/settings/SettingsWindowFrame.qml')
assert 'contentHeight: pageColumn.implicitHeight+48' in frame
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
assert 'LauncherStyle.anchor(' in overlay
assert 'SettingsStore.launcherWidth' in source('config/LauncherStyle.qml')  # configurable, monitor-clamped geometry
assert 'Store.launcherVisible' in overlay
assert 'WlrLayer.Overlay' in overlay
launcher=source('modules/main/MiniLauncher.qml')
controller=source('components/LauncherController.qml')
results=source('components/LauncherResults.qml')
assert 'DesktopEntries.applications' in controller and 'results = ordered' in controller
assert re.search(r'onQueryChanged:\s*\{[^}]*rebuild\(\)', controller)
assert 'property alias results: backend.results' in launcher
shell=source('shell.qml')
assert 'LauncherOverlay { screen: Store.launcherScreen }' in shell
store=source('config/Store.qml')
assert 'function toggleLauncher(screen, anchor)' in store
indicator = source('modules/main/IndicatorPopup.qml')
assert 'MiniLauncher {' not in indicator and 'LauncherOverlay {' not in indicator
assert 'function onLauncherVisibleChanged()' in indicator  # release the old popup's focus before handoff
assert 'width:ListView.view.width;height:root.rowHeight' in results
assert 'Math.max(SettingsStore.launcherRowHeight,SettingsStore.launcherShowIcons ? iconSize+16 : 28)' in results
print('RC5 Settings refactor: page split, intrinsic sizing, launcher centering and persistence checks passed')
