#!/usr/bin/env python3
"""Offline regression checks; does not record a real screen or require Hyprland."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/rustiq-record.py'


def call(env, command):
    result = subprocess.run([sys.executable, str(HELPER), command], env=env,
                            capture_output=True, text=True, timeout=8)
    data = json.loads(result.stdout.strip())
    assert result.returncode == (0 if data['ok'] else 1), result.stderr
    return data


def check_recorder():
    with tempfile.TemporaryDirectory() as temp:
        path = Path(temp)
        mockbin = path / 'bin'
        mockbin.mkdir()
        slurp = mockbin / 'slurp'
        slurp.write_text('#!/bin/sh\nprintf "0,0 1280x720\\n"\n')
        slurp.chmod(0o755)
        recorder = mockbin / 'wf-recorder'
        recorder.write_text('''#!/usr/bin/env python3
import signal,time,sys
running=True
def stop(*args):
    global running
    running=False
signal.signal(signal.SIGINT,stop)
while running: time.sleep(0.05)
''')
        recorder.chmod(0o755)
        env = os.environ.copy()
        env.update(XDG_RUNTIME_DIR=str(path / 'run'), XDG_VIDEOS_DIR=str(path / 'videos'),
                   PATH=str(mockbin) + ':' + env.get('PATH', ''))
        assert call(env, 'status')['active'] is False
        started = call(env, 'start-screen')
        assert started['active'] and started['file'].endswith('.mp4'), started
        assert call(env, 'status')['active'] is True
        assert not call(env, 'start-region')['ok'], 'Must not launch 2 simultaneous recorders'
        assert call(env, 'stop')['ok']
        time.sleep(.25)
        assert not call(env, 'status')['active']
        assert call(env, 'start-region')['ok']
        assert call(env, 'stop')['ok']


def check_source():
    appearance = (ROOT / 'modules/settings/pages/SettingsAppearancePage.qml').read_text()
    assert 'color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }\n        Rectangle {' not in appearance
    wifi = (ROOT / 'services/WifiService.qml').read_text()
    popup = (ROOT / 'modules/main/IndicatorPopup.qml').read_text()
    menu = (ROOT / 'modules/main/ContextMenu.qml').read_text()
    assert 'DeviceType.Wired' in wifi and 'dev.connected && dev.hasLink' in wifi
    assert 'MiniEthernetInfo' in popup and 'kind === "ethernet"' in popup
    for action in ('start-screen', 'start-region', 'start-audio', 'stop', 'portal-check'):
        assert action in menu
    assert 'singleton ScreenRecorder 1.0 ScreenRecorder.qml' in (ROOT / 'services/qmldir').read_text()


if __name__ == '__main__':
    check_source()
    check_recorder()
    print('PASS: QML source, wired detection, recording lifecycle with fake wf-recorder, portal menu wiring')
