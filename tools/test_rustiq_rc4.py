#!/usr/bin/env python3
"""RC4 hermetic checks. They do NOT substitute a real Qt/Wayland session."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
try:
    from fontTools.ttLib import TTFont
except ImportError:
    TTFont = None

ROOT = Path(__file__).resolve().parents[1]
read = lambda p: (ROOT / p).read_text()

for name in ('NotificationCenter',):
    assert f'singleton {name} 1.0 {name}.qml' in read('services/qmldir')
assert 'onNotification: notification => root.receive(notification)' in read('services/NotificationCenter.qml')
assert 'NotificationToasts {}' in read('shell.qml')
assert 'BarNotifications' in read('modules/bar/BarMain.qml')
assert 'NotificationCenter.doNotDisturb' in read('modules/bar/BarNotifications.qml')
assert 'SystemDashboard' in read('modules/main/IndicatorPopup.qml')
assert 'required property int index' in read('modules/main/SystemDashboard.qml')
assert 'read-only' in read('scripts/rustiq-processes.py').lower()
assert 'data.ok && currentAction.action === "apply"' in read('modules/bar/BarMonitors.qml')
assert 'hyprctl' in read('scripts/rustiq-display.py')
assert 'WlrLayer.Bottom' in read('modules/main/DesktopWidgets.qml')
assert 'SettingsStore.dockAutoHide' in read('modules/main/RusticDock.qml')
assert 'function openSearchResult' in read('modules/settings/SettingsWindow.qml')
assert 'MarginSlider {' in read('modules/settings/SettingsWindow.qml')
assert 'MouseArea' in read('components/MarginSlider.qml')
for name in ('desktopCalendar', 'desktopSystem', 'desktopClock', 'showDock', 'dockAutoHide',
             'dockFiles', 'dockBrowser', 'dockSettings', 'dockTaskView', 'dockAI',
             'showNotifications', 'showTaskView'):
    store = read('config/SettingsStore.qml')
    assert f'property bool {name}:' in store
    assert f'{name}: {name},' in store
    assert name in read('modules/settings/SettingsWindow.qml')

if TTFont is not None:
    cmap = TTFont(str(ROOT / 'assets/google.ttf')).getBestCmap()
    for cp in (0xe7f4, 0xf190, 0xe916, 0xe8b5, 0xe8b6, 0xe2c7, 0xe80b):
        assert cp in cmap, hex(cp)

result = subprocess.run([sys.executable, str(ROOT / 'scripts/rustiq-processes.py')], capture_output=True, text=True, check=True)
proc = json.loads(result.stdout)
assert isinstance(proc['processes'], list) and isinstance(proc['load'], list)
assert all('cpu' in item and 'memMiB' in item and 'pid' in item for item in proc['processes'])

monitors = [{'name':'eDP-1','x':0,'y':0,'width':1920,'height':1080,'scale':1,'mode':'1920x1080@60'},
            {'name':'DP-1','x':1920,'y':0,'width':2560,'height':1440,'scale':1.25,'mode':'2560x1440@144'}]
# Verify positive and negative readback using fake hyprctl; no compositor mutated.
for mismatch in (False, True):
    with tempfile.TemporaryDirectory() as d:
        fake = Path(d)/'hyprctl'
        fake.write_text('#!/usr/bin/env python3\n'
                        'import json,sys\n'
                        'if sys.argv[1:] == ["-j", "monitors"]:\n'
                        ' print(json.dumps([{"name":"eDP-1","x":0,"y":0,"width":1920,"height":1080,"scale":1},'
                        '{"name":"DP-1","x":'+ ('0' if mismatch else '1920') + ',"y":0,"width":2560,"height":1440,"scale":1.25}]))\n'
                        'else: print("ok")\n')
        fake.chmod(0o755)
        env = dict(os.environ, PATH=d + ':' + os.environ.get('PATH', ''))
        run = subprocess.run([sys.executable, str(ROOT/'scripts/rustiq-display.py'), 'apply'], input=json.dumps(monitors),
                             text=True, capture_output=True, env=env)
        payload = json.loads(run.stdout)
        assert payload['ok'] is (not mismatch), payload
        assert (run.returncode == 0) is (not mismatch), payload

print('PASS: RC4 notifications, system view, desktop/dock settings, glyphs, process snapshot, display verification')
