#!/usr/bin/env python3
"""No pacman operation: PTY progress fixtures & QML persistence contract tests."""
import importlib.util
from pathlib import Path
import json
import os
import pty
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
UPDATER = ROOT / 'scripts' / 'rustiq-updater.py'
spec = importlib.util.spec_from_file_location('rustiq_updater', UPDATER)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_progress():
    p = mod.PacmanProgress()
    assert p.progress == -1 and p.kind == 'unknown'
    p.observe(':: Retrieving packages...')
    assert p.phase == 'downloading' and p.progress == -1
    p.observe('rustiq-package  25.0 MiB  2.0 MiB/s  00:12 [###] 68%')
    assert p.kind == 'item' and p.progress == 68 and p.phase == 'downloading'
    p.observe('(1/4) upgrading desktop-package')
    assert p.progress == -1 and p.kind == 'counter' and p.completed == 1 and p.total == 4
    p.observe('checking package integrity')
    assert p.kind == 'unknown' and p.progress == -1
    p.observe('(2/4) upgrading second-package')
    assert p.completed == 2 and p.total == 4


def test_stream():
    with tempfile.TemporaryDirectory() as td:
        mod.ROOT = Path(td)
        mod.STATE = mod.ROOT / 'status.json'
        mod.LOG = mod.ROOT / 'pacman.log'
        mod.LOCK = mod.ROOT / 'upgrade.lock'
        m, s = pty.openpty()
        fixture = ("import sys,time\n"
                   "sys.stdout.write(':: Retrieving packages...\\r')\n"
                   "sys.stdout.write('a-package 1.0 MiB 100 KiB/s 25%\\r')\n"
                   "sys.stdout.write('a-package 1.0 MiB 100 KiB/s 77%\\r')\n"
                   "sys.stdout.write('(1/2) upgrading a-package\\n')\n"
                   "sys.stdout.write('(2/2) upgrading b-package\\n')\n"
                   "sys.stdout.flush()\n")
        proc = subprocess.Popen([sys.executable, '-u', '-c', fixture], stdout=s, stderr=s)
        os.close(s)
        state = mod.PacmanProgress()
        mod.stream_pacman(proc, m, state)
        os.close(m)
        assert proc.wait(timeout=5) == 0
        assert state.phase == 'installing'
        assert (state.completed, state.total) == (2, 2)
        assert state.progress == -1
        assert any('77%' in line for line in mod.status()['lines']), mod.status()['lines']


def test_launcher():
    store=(ROOT/'config/SettingsStore.qml').read_text()
    overlay=(ROOT/'modules/main/LauncherOverlay.qml').read_text()
    launch=(ROOT/'modules/main/MiniLauncher.qml').read_text()
    page=(ROOT/'modules/settings/pages/SettingsLauncherPage.qml').read_text()
    settings=(ROOT/'modules/settings/SettingsWindow.qml').read_text()
    for field in ['launcherWidth','launcherHeight','launcherIconSize','launcherRowHeight','launcherFavoriteColumns']:
        assert f'property int {field}:' in store
        assert f'{field}: {field}' in store
        assert f'"{field}"' in store
        assert field in page
    assert 'SettingsStore.launcherWidth' in overlay and 'SettingsStore.launcherHeight' in overlay
    assert 'SettingsStore.launcherIconSize' in launch
    assert 'SettingsStore.launcherFavoriteColumns' in launch
    assert 'SettingsLauncherPage {}' in settings
    assert 'showLauncher' in store

if __name__ == '__main__':
    for f in [test_progress, test_stream, test_launcher]:
        f()
        print('PASS', f.__name__)
