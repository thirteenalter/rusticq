#!/usr/bin/env python3
"""Source-level invariants for the hotfix; cannot replace Quickshell runtime."""
from pathlib import Path
import re
base = Path(__file__).resolve().parents[1]
store = (base / "config/SettingsStore.qml").read_text()
bar = (base / "modules/main/Bar.qml").read_text()
settings = (base / "modules/settings/SettingsWindow.qml").read_text()
assert 'property string barMode:' in store
assert 'barMode: barMode' in store
assert 'data.barMode' in store
for mode in ('compact', 'separated', 'professional', 'simple'):
    assert mode in bar and mode in store and mode in settings, mode
assert 'Store.toggleQuick(barWindow.screen)' in bar
assert 'Store.toggleAi(barWindow.screen)' in bar
assert bar.count('Workspaces {') == 1 and bar.count('Indicators {') == 1
for fname in ('BarBattery.qml', 'BarBluetooth.qml', 'BarWifi.qml'):
    s = (base / 'modules/bar' / fname).read_text()
    assert 'Theme.sectionPadding' in s, fname
    assert 'SectionHeader {' in s, fname
assert 'UPower' in (base/'services/BatteryService.qml').read_text()
print('PASS: 4 bar modes, SettingsStore persistence, shared card geometry, single bar component instances')
