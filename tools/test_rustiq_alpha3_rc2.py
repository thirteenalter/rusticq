#!/usr/bin/env python3
"""Alpha 3 RC2 source regressions. Runtime still requires Wayland/Quickshell."""
from pathlib import Path
import json, subprocess, os, tempfile
ROOT=Path(__file__).resolve().parents[1]
get=lambda x:(ROOT/x).read_text()

popup=get('modules/main/IndicatorPopup.qml')
assert 'color: "transparent"' in popup
assert 'color: Theme.background' in popup and 'border.width: popup.singleSystem ? 0 : 1' in popup
assert all(f'{name} {{ standalone: true }}' in popup for name in ['BarWifi','BarBluetooth','BarBattery'])

store=get('config/SettingsStore.qml')
data=json.loads(get('user-settings.json'))
keys={
    'cleanRightDetails':True,
    'showMenuEdit':True,'showMenuView':True,'showMenuShare':True,
    'showMenuFile':False,'showMenuShell':False,'showMenuTools':False,
    'showArch':True,'showTime':True,'showDate':True,'showWifi':True,
    'showBluetooth':True,'showBattery':True,'showAudio':True,'showQuickControl':True
}
for key,default in keys.items():
    assert f'property bool {key}: {str(default).lower()}' in store, key
    assert (f'{key}: {key},' in store or (key == 'cleanRightDetails' and 'cleanRightDetails: cleanRightMode === "details"' in store)), key
    assert data[key] == default, key
assert 'if (typeof data[key] === "boolean") root[key] = data[key]' in store

bar=get('modules/main/Bar.qml')
indicator=get('components/Indicators.qml')
vertical=get('modules/main/VerticalBarContent.qml')
for key in ['showArch','showTime','showDate','showWifi','showBluetooth','showBattery','showAudio','showQuickControl']:
    assert f'SettingsStore.{key}' in bar+indicator, key
    assert f'SettingsStore.{key}' in vertical or key in ['showAudio'], key
assert 'showDetails: !barWindow.cleanCompactMode || SettingsStore.cleanRightMode' in bar
assert 'property bool showCaption: true' in get('components/InfoSegment.qml')
assert 'visible: root.showCaption' in get('components/InfoSegment.qml')
assert 'visible: true' in get('components/Battery.qml')
assert 'root.percentage + "%"' in get('components/Audio.qml')
assert 'showCaption: root.showDetails' in get('components/Clock.qml')

menu=get('modules/main/ContextMenu.qml')
menubar=get('components/ContextMenuBar.qml')
for cat in ['file','edit','view','share','shell','tools']:
    assert f'key: "{cat}"' in menu+menubar,cat
assert 'Quickshell.shellPath("scripts/rustiq-menu-action.sh")' in menu
script=ROOT/'scripts/rustiq-menu-action.sh'
r=subprocess.run(['sh',str(script),'arbitrary-shell-command'],capture_output=True,text=True)
assert r.returncode==2 and 'Unknown action' in r.stderr
assert 'eval ' not in get('scripts/rustiq-menu-action.sh')

settings=get('modules/settings/SettingsWindow.qml')
assert 'Clean Compact · Right-side labels' in settings
assert 'delegate: SettingsToggle {}' in settings
assert 'RUSTIQ / ALPHA 3 RC4' in settings

print('PASS: RC2 opaque widget backgrounds, right-only detail selector, 14 persistent flags, per-icon visibility, six menu categories, menu action allowlist, settings UI')
