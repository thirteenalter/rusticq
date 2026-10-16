#!/usr/bin/env python3
"""Targeted source-level regressions for RC5 runtime repair (not a QML desktop test)."""
from pathlib import Path
from fontTools.ttLib import TTFont
import re

root = Path(__file__).resolve().parent.parent

def read(name):
    path = root / name
    assert path.is_file(), f'missing {name}'
    return path.read_text()

launcher = read('modules/main/MiniLauncher.qml')
assert 'DesktopEntries.applications.values' in launcher
assert 'entries.length' in launcher and 'entries[i]' in launcher
assert 'applications.count' not in launcher and 'entries.get(' not in launcher
assert 'Keys.onEscapePressed' in launcher
assert 'results = found' in launcher and 'onQueryChanged: rebuild()' in launcher
assert 'function onApplicationsChanged()' in launcher
assert 'undefined apps' not in launcher

overlay = read('modules/main/LauncherOverlay.qml')
assert 'Keys.onEscapePressed' not in overlay, 'Keys must not attach to PanelWindow'
assert 'anchors.centerIn: parent' in overlay
assert 'Store.launcherVisible' in overlay

widgets = read('modules/main/DesktopWidgets.qml')
widget_window = read('modules/main/DesktopWidgetWindow.qml')
for kind in ('clock', 'calendar', 'system', 'media', 'weather', 'connectivity'):
    assert f'kind: "{kind}"' in widgets
for flag in ('desktopClock', 'desktopCalendar', 'desktopSystem', 'desktopMedia', 'desktopWeather', 'desktopConnectivity'):
    assert flag in widget_window, flag
assert 'cards.implicitHeight' in widget_window
assert 'Quickshell.Services.Mpris' in widget_window
assert 'Mpris.players.values' in widget_window
assert 'MetricWave' in widget_window

settings = read('config/SettingsStore.qml')
page = read('modules/settings/pages/SettingsWidgetsPage.qml')
for flag in ('desktopMedia', 'desktopWeather', 'desktopConnectivity'):
    assert f'property bool {flag}: false' in settings
    assert f'{flag}: {flag}' in settings
    assert flag in page
    assert f'"{flag}"' in settings

dock = read('modules/main/RusticDock.qml')
assert 'expanded ? 94 : 18' in dock
assert 'desiredDockWidth' in dock
assert 'Store.toggleLauncher(dock.screen)' in dock
assert 'Layout.preferredWidth: 46' in dock

dashboard = read('modules/main/SystemDashboard.qml')
assert 'showTrends' in dashboard and 'root.cpuHistory' in dashboard and 'root.memHistory' in dashboard
assert 'MetricWave' in dashboard and 'root.showTrends' in dashboard

wave = read('components/MetricWave.qml')
assert 'Canvas' in wave and 'ctx.stroke()' in wave
font = TTFont(root/'assets/google.ttf', lazy=True)
cmap = font.getBestCmap()
new_files = ('modules/main/DesktopWidgetWindow.qml', 'modules/main/SystemDashboard.qml', 'modules/settings/pages/SettingsWidgetsPage.qml')
missing = []
for file in new_files:
    for codepoint in re.findall(r'\\u([0-9a-fA-F]{4})', read(file)):
        if int(codepoint,16) not in cmap:
            missing.append((file,codepoint))
assert not missing, f'Glyphs unavailable: {missing}'

print('RC5 runtime repair checks passed: launcher model/focus, dock bounds, scrollable widgets, MPRIS, waves, settings persistence and font glyphs')
