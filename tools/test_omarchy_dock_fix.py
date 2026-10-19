#!/usr/bin/env python3
"""Offline regression: no package upgrades or terminal sessions are launched."""
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import mock
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('rustiq_updater', ROOT / 'scripts/rustiq-updater.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


def test_guard_detection():
    sample = '''(1/2) Checking Omarchy update entrypoint...
Woah partner...
This looks like a direct pacman system upgrade. Omarchy updates should normally
run through:
omarchy update
error: failed to commit transaction (failed to run transaction hooks)
'''
    assert mod.omarchy_guard_blocked(sample.splitlines())
    assert not mod.omarchy_guard_blocked(['Checking available disk space [100%]'])


def test_safe_omarchy_launch():
    with TemporaryDirectory() as tmp:
        path = Path(tmp)
        with mock.patch.object(mod, 'ROOT', path), \
             mock.patch.object(mod, 'STATE', path / 'status.json'), \
             mock.patch.object(mod, 'LOG', path / 'pacman.log'), \
             mock.patch.object(mod, 'LOCK', path / 'upgrade.lock'), \
             mock.patch.object(mod.shutil, 'which', side_effect=lambda cmd: '/mock/bin/' + cmd if cmd in ('omarchy', 'xdg-terminal-exec') else None), \
             mock.patch.object(mod.subprocess, 'Popen') as fake:
            fake.return_value.pid = 99423
            cmd = mod.choose_terminal()
            assert cmd == ['/mock/bin/xdg-terminal-exec', '--', '/mock/bin/omarchy', 'update']
            result = mod.start_omarchy_update()
            assert result['ok'] and result['external']
            args, kwargs = fake.call_args
            assert args[0] == cmd
            assert not any('pacman' in arg for arg in args[0])
            state = mod.current_state()
            assert state['state'] == 'external'
            assert state['progress'] == -1
            assert not state['message'].lower().startswith('success')


def test_recovery_from_old_guard_log():
    with TemporaryDirectory() as tmp:
        path = Path(tmp)
        path.joinpath('pacman.log').write_text('Woah partner...\nomarchy update\nerror: failed to commit transaction\n')
        path.joinpath('status.json').write_text('{"state":"failed","message":"Update failed"}')
        with mock.patch.object(mod, 'ROOT', path), \
             mock.patch.object(mod, 'STATE', path / 'status.json'), \
             mock.patch.object(mod, 'LOG', path / 'pacman.log'), \
             mock.patch.object(mod, 'OMARCHY_GUARD', path / 'guard-not-found'), \
             mock.patch.object(mod.shutil, 'which', return_value=None):
            response = mod.status()
            assert response['omarchyGuard'] is True
            assert response['recommendedCommand'] == 'omarchy update'
            assert 'Omarchy blocked' in response['message']


def test_dock_real_clients_model():
    dock = (ROOT / 'modules/main/RusticDock.qml').read_text()
    assert 'scripts/rustiq-running-apps.py' in dock
    assert 'model: SettingsStore.dockRunningApps ? dock.runningApps : []' in dock
    assert 'runningApps.length' in dock
    assert 'Math.ceil(contentRow.implicitWidth) + dockPadding * 2' in dock
    assert 'dock.runningApps = []' in dock
    assert 'focus", runningApp.modelData.address' in dock
    ui = (ROOT / 'modules/settings/pages/SettingsUpdaterPage.qml').read_text()
    assert 'root.omarchy ? "Open Omarchy update"' in ui
    assert 'root.omarchy ? "Open Omarchy terminal"' in ui
    assert 'OMARCHY_ALLOW_DIRECT_PACMAN=1' not in (ROOT / 'scripts/rustiq-updater.py').read_text()


if __name__ == '__main__':
    for func in (test_guard_detection, test_safe_omarchy_launch, test_recovery_from_old_guard_log, test_dock_real_clients_model):
        func()
        print('PASS', func.__name__)
