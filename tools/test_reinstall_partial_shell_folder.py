#!/usr/bin/env python3
"""An incomplete installed shell must not permanently block re-enable."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/rustiq-desktop-integration.py'


def fixture(root):
    home = root / 'home'
    config = home / '.config/hypr'
    config.mkdir(parents=True)
    (config / 'hyprland.lua').write_text('require("default.hypr.omarchy")\nrequire("hypr.bindings")\n')
    (config / 'bindings.lua').write_text('-- original\n')
    omarchy = root / 'omarchy/default/hypr'
    omarchy.mkdir(parents=True)
    (omarchy / 'autostart.lua').write_text('hl.exec_cmd("omarchy-launch-shell")\n')
    (omarchy / 'bindings.lua').write_text('-- default\n')
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               XDG_STATE_HOME=str(home / '.local/state'),
               XDG_DATA_HOME=str(home / '.local/share'),
               OMARCHY_PATH=str(root / 'omarchy'))
    env.pop('HYPRLAND_INSTANCE_SIGNATURE', None)
    return home, env


def cli(env, *args, successful=True):
    proc = subprocess.run([sys.executable, str(SCRIPT), *args], env=env,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=50)
    assert proc.stdout, proc.stderr
    result = json.loads(proc.stdout)
    assert result.get('ok') == successful, (result, proc.stderr)
    return result


def test_partial_shell_folder():
    for layout in ('empty', 'shell-only', 'other-files'):
        with tempfile.TemporaryDirectory() as temp:
            home, env = fixture(Path(temp))
            folder = home / '.local/share/rusticq/shell'
            folder.mkdir(parents=True)
            if layout == 'shell-only':
                (folder / 'shell.qml').write_text('Legacy source\n')
            if layout == 'other-files':
                (folder / 'user-settings.json').write_text('{"private":true}\n')
            assert cli(env, 'status')['reinstall']['ready']
            installed = cli(env, 'enable', '--confirm', 'ENABLE RUSTICQ')
            assert installed['integration']['state'] == 'installed', installed
            archived = [Path(x) for x in installed['recovered_files'] if x.endswith('/shell')]
            assert len(archived) == 1 and archived[0].is_dir(), installed
            if layout == 'shell-only':
                assert (archived[0] / 'shell.qml').read_text() == 'Legacy source\n'
            if layout == 'other-files':
                assert json.loads((archived[0] / 'user-settings.json').read_text())['private']
            assert (folder / 'shell.qml').exists()
            assert (folder / 'scripts/rustiq-desktop-integration.py').is_file()
            reverted = cli(env, 'revert', '--confirm', 'RESTORE OMARCHY')
            assert reverted['integration']['state'] == 'restored'
            assert (archived[0]).is_dir()  # Still preserved after restore


def test_symlink_blocked_without_overwriting_destination():
    with tempfile.TemporaryDirectory() as temp:
        home, env = fixture(Path(temp))
        actual = home / 'anything'
        actual.mkdir()
        (actual / 'private').write_text('keep me')
        link = home / '.local/share/rusticq/shell'
        link.parent.mkdir(parents=True)
        link.symlink_to(actual, target_is_directory=True)
        result = cli(env, 'enable', '--confirm', 'ENABLE RUSTICQ', successful=False)
        assert 'symlink' in result['message'].lower(), result
        assert link.is_symlink() and (actual / 'private').read_text() == 'keep me'
        assert not (home / '.local/state/rusticq/integration/manifest.json').exists()


def test_in_use_shell_blocks_parking_and_preserves_data():
    with tempfile.TemporaryDirectory() as temp:
        home, env = fixture(Path(temp))
        with patch.dict(os.environ, env):
            name = 'test_stale_shell_installer'
            spec = importlib.util.spec_from_file_location(name, SCRIPT)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            folder = mod.DATA
            folder.mkdir(parents=True)
            (folder / 'important').write_text('do not move')
            with patch.object(mod, 'installed_shell_processes', return_value=[1234]):
                report = mod.reinstall_readiness()
                assert not report['ready'] and report['shell_state'] == 'in_use'
                assert 'Log out' in report['shell_note']
                try:
                    mod.park_unmanaged_leftovers()
                except ValueError as error:
                    assert 'Log out' in str(error), error
                else:
                    raise AssertionError('Unexpected park of running shell')
            assert (folder / 'important').read_text() == 'do not move'


def test_failure_after_parking_restores_previous_directory():
    with tempfile.TemporaryDirectory() as temp:
        home, env = fixture(Path(temp))
        with patch.dict(os.environ, env):
            spec = importlib.util.spec_from_file_location('test_recovery_install', SCRIPT)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            folder = mod.DATA
            folder.mkdir(parents=True)
            (folder / 'unique').write_text('previous user file')
            # Simulate a failure in copytree, after the original has already
            # been moved to recovery history. No live file should be destroyed.
            def simulated_failure():
                mod.DATA.mkdir(parents=True)
                (mod.DATA / 'partial').write_text('incomplete copied file')
                raise OSError('simulated disk failure')
            with patch.object(mod, 'safe_copy_shell', side_effect=simulated_failure):
                try:
                    mod.enable_permanent('ENABLE RUSTICQ')
                except OSError as error:
                    assert 'simulated disk failure' in str(error)
                else:
                    raise AssertionError('Expected simulated failure')
            assert (folder / 'unique').read_text() == 'previous user file'
            assert not (folder / 'partial').exists()
            assert not mod.META.exists()


if __name__ == '__main__':
    test_partial_shell_folder()
    test_symlink_blocked_without_overwriting_destination()
    test_in_use_shell_blocks_parking_and_preserves_data()
    test_failure_after_parking_restores_previous_directory()
    print('OK partial-shell recovery, symlink protection, live-process guard, rollback')
