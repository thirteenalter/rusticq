#!/usr/bin/env python3
"""Static regression guard for System Monitor / Dock routing fix."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
monitor = (ROOT / 'modules/main/SystemMonitorWindow.qml').read_text()
dock = (ROOT / 'modules/main/RusticDock.qml').read_text()
settings = (ROOT / 'modules/settings/pages/SettingsDockPage.qml').read_text()
context = (ROOT / 'modules/main/ContextMenu.qml').read_text()
store = (ROOT / 'config/Store.qml').read_text()

assert 'title: "RusticQ · System Monitor"' in monitor
assert 'onVisibleChanged:' in monitor
assert 'Store.systemMonitorVisible = false' in monitor
assert 'icon: "\\ue5cd"' not in monitor, 'Unexpected close icon in monitor header'
assert 'onClicked: Store.systemMonitorVisible = false' not in monitor
assert 'label:"Monitor"' in dock and 'action:"system-monitor"' in dock
assert 'app.modelData.action === "system-monitor"' in dock
assert 'Store.systemMonitorVisible = true' in dock
assert 'Store.taskViewVisible' not in dock
assert 'label:"System Monitor"' in settings and 'key:"dockTaskView"' in settings
assert 'Store.systemMonitorVisible = true' in context
assert 'property bool systemMonitorVisible: false' in store
print('PASS System Monitor header / Dock shortcut regression')
