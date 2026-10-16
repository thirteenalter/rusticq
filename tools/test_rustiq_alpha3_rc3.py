#!/usr/bin/env python3
"""RC3 source and hermetic monitor-helper checks (not a QML runtime test)."""
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
source = lambda name: (ROOT / name).read_text()
settings = source('config/SettingsStore.qml')
bar = source('modules/main/Bar.qml')
ui = source('modules/settings/SettingsWindow.qml')
monitor = source('modules/bar/BarMonitors.qml')

for required in ('property string cleanRightMode: "details"', 'marginOverrides',
                 'function setBarMargin(', 'function resetBarMargins(', 'cleanRightMode: cleanRightMode',
                 'marginOverrides: marginOverrides'):
    assert required in settings, required
assert 'data.cleanRightDetails ? "details" : "icons"' in settings
for edge in ('top', 'bottom', 'left', 'right'):
    assert f'SettingsStore.marginFor("{edge}"' in bar, edge
assert 'rightGroupHover.hovered' in bar
assert all(key in ui for key in ('On hover', 'Icons only', 'With details', 'Realtime margin editor',
                                 'Reset mode', 'Bar position', 'Bar layout mode'))
for part in ('drag.target: screenChip', 'chooseMode(', 'placeNextTo(', 'Apply layout', 'Export Lua',
             'modeButton.modelData', 'Refresh', 'display.scale'):
    assert part in monitor, part
for comp in ('Wifi.qml','Bluetooth.qml'):
    assert '!root.cleanStyle && hover.hovered' in source('components/'+comp)

spec = importlib.util.spec_from_file_location('helper', ROOT/'scripts/rustiq-display.py')
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
base = [dict(name='eDP-1', mode='1920x1080@60', x=0, y=0, scale=1, width=1920, height=1080),
        dict(name='DP-1', mode='2560x1440@144', x=1920, y=0, scale=1.25, width=2560, height=1440)]
validated = h.validate(base)
assert 'hl.monitor({' in h.make_lua(validated)
assert 'position = "1920x0"' in h.make_lua(validated)
for invalid in ([dict(base[0], name='eDP-1;os.execute("evil")')],
                [base[0], dict(base[1], x=100)],
                [dict(base[0], mode='1920x1080@60;echo')],
                [dict(base[0], scale=0)]):
    try:
        h.validate(invalid)
        assert False, f'invalid accepted: {invalid}'
    except ValueError:
        pass
with tempfile.TemporaryDirectory() as d:
    home = pathlib.Path(d)
    fake = home/'hyprctl'
    fake.write_text('#!/usr/bin/env python3\n'
                    'import json,sys\n'
                    'if sys.argv[1:] == ["-j", "monitors"]:\n'
                    ' print(json.dumps([{"name":"eDP-1","x":0,"y":0,"width":1920,"height":1080,"scale":1},'
                    '{"name":"DP-1","x":1920,"y":0,"width":2560,"height":1440,"scale":1.25}]))\n'
                    'else: print("ok")\n')
    fake.chmod(0o755)
    import os
    env = dict(os.environ, HOME=d, PATH=f'{d}:{os.environ["PATH"]}')
    for action in ('dry-run', 'export', 'apply'):
        r = subprocess.run([sys.executable, str(ROOT/'scripts/rustiq-display.py'), action],
                           input=json.dumps(base), text=True, capture_output=True, env=env)
        assert r.returncode == 0, (action,r.stderr,r.stdout)
        assert json.loads(r.stdout)['ok'], (action, r.stdout)
    snippet = home/'.config/rustiq/monitors.lua'
    assert snippet.exists()
    assert 'hl.monitor' in snippet.read_text()
    assert not (home/'.config/hypr').exists(), 'should never edit Hyprland config automatically'
print('PASS: RC3 hover, per-mode margins, display previews/actions, Lua helper validation and export')
