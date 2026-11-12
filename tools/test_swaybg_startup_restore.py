#!/usr/bin/env python3
"""Tests for persisted startup wallpaper, multi-output, and bare-uwsm cleanup.

Does not launch an actual Wayland compositor or kill real processes.
"""
from pathlib import Path
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/rusticq-wallpaper.py'


def load():
    spec = importlib.util.spec_from_file_location('rusticq_wallpaper_startup_tests', SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class RestoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.homedir = Path(self.temp.name) / 'home'
        self.homedir.mkdir()
        self.image = self.homedir / 'Picture.jpg'
        self.image.write_bytes(b'placeholder image')
        self.cfg = self.homedir / '.config'
        self.environment = patch.dict(os.environ, HOME=str(self.homedir), XDG_CONFIG_HOME=str(self.cfg))
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.m = load()

    def test_saved_profile_is_private_and_explicitly_restored(self):
        m = self.m
        result = m.configure_restore(True, str(self.image), 'fill')
        self.assertTrue(result['auto_restore'])
        self.assertEqual(m.read_restore_profile()['image'], str(self.image))
        self.assertEqual(m.read_restore_profile()['output'], '*')
        self.assertEqual(m.restore_profile_path().stat().st_mode & 0o777, 0o600)
        with patch.object(m, 'apply_swaybg', return_value={'ok': True, 'backend': 'swaybg', 'pid': 1234}) as apply:
            restored = m.restore_wallpaper()
        self.assertTrue(restored['ok'])
        self.assertTrue(restored['auto_restore'])
        apply.assert_called_once_with(self.image, 'fill', '*', False)

    def test_disable_restoration_is_respected_in_all_shell_instances(self):
        m = self.m
        m.configure_restore(True, str(self.image), 'fill')
        m.configure_restore(False)
        with patch.object(m, 'apply_swaybg') as apply:
            result = m.restore_wallpaper(str(self.image), 'fill')
        self.assertTrue(result['skipped'])
        apply.assert_not_called()

    def test_legacy_restoration_migrates_when_profile_missing(self):
        m = self.m
        with patch.object(m, 'apply_swaybg', return_value={'ok': True, 'backend': 'swaybg'}) as apply:
            restored = m.restore_wallpaper(str(self.image), 'fit', True)
        self.assertTrue(restored['ok'])
        self.assertEqual(m.read_restore_profile()['mode'], 'fit')
        self.assertTrue(m.read_restore_profile()['replace_conflicts'])
        apply.assert_called_once_with(self.image, 'fit', '*', True)

    def test_no_profile_no_autostart(self):
        with patch.object(self.m, 'apply_swaybg') as apply:
            self.assertTrue(self.m.restore_wallpaper()['skipped'])
        apply.assert_not_called()

    def test_image_missing_reports_error_without_running_backend(self):
        m = self.m
        m.configure_restore(True, str(self.image), 'fill')
        self.image.unlink()
        with patch.object(m, 'apply_swaybg') as apply:
            result = m.restore_wallpaper()
        self.assertFalse(result['ok'])
        self.assertIn('Startup wallpaper failed:', result['message'])
        apply.assert_not_called()

    def test_symlinked_config_file_rejected(self):
        m = self.m
        target = m.restore_profile_path()
        target.parent.mkdir(parents=True)
        target.symlink_to(self.image)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            m.configure_restore(True, str(self.image))

    def test_failed_apply_does_not_write_profile(self):
        m = self.m
        with patch.object(m, 'apply_swaybg', side_effect=RuntimeError('Wayland refused wallpaper')):
            with patch('builtins.print') as output:
                code = m.apply(str(self.image), 'swaybg', remember=True)
        self.assertEqual(code, 1)
        self.assertFalse(m.restore_profile_path().exists())

    def test_successful_apply_remembers_while_other_backend_disables(self):
        m = self.m
        with patch.object(m, 'apply_swaybg', return_value={'ok': True, 'message': 'Applied', 'backend': 'swaybg', 'pid': 22}):
            with patch('builtins.print'):
                self.assertEqual(m.apply(str(self.image), 'swaybg', remember=True), 0)
        self.assertTrue(m.read_restore_profile()['enabled'])
        with patch.object(m.shutil,'which',return_value='/usr/bin/awww'), patch.object(m, 'run',return_value=(True, '')):
            with patch('builtins.print'):
                self.assertEqual(m.apply(str(self.image), 'awww', remember=True), 0)
        self.assertFalse(m.read_restore_profile()['enabled'])

    def test_bare_swaybg_only_recognized_on_same_display(self):
        m = self.m
        entry = {'name':'swaybg','pid':222,'start':'111'}
        with patch.object(m, 'matches_wayland_session', return_value=True), \
             patch.object(Path, 'read_bytes', return_value=b'/usr/bin/swaybg\0'):
            self.assertTrue(m.unconfigured_swaybg(entry))
        with patch.object(m, 'matches_wayland_session', return_value=True), \
             patch.object(Path, 'read_bytes', return_value=b'/usr/bin/swaybg\0-i\0/wall.jpg\0'):
            self.assertFalse(m.unconfigured_swaybg(entry))
        with patch.object(m, 'matches_wayland_session', return_value=False):
            self.assertFalse(m.unconfigured_swaybg(entry))

    def test_bare_process_replaced_only_after_new_process_starts(self):
        m = self.m
        fake = Mock(pid=6202)
        fake.poll.return_value = None
        entry = {'pid':6201,'name':'swaybg','start':'1'}
        orig_stat = Path.stat
        orig_read = Path.read_text
        def stat_for_old(path, *args, **kwargs):
            if str(path).startswith('/proc/6201'):
                return type('ProcStat', (), {'st_uid':os.getuid()})()
            return orig_stat(path, *args, **kwargs)
        def read_old_name(path, *args, **kwargs):
            return 'swaybg' if str(path) == '/proc/6201/comm' else orig_read(path, *args, **kwargs)
        with patch.object(m, 'runtime_dir', return_value=self.homedir), \
             patch.object(m, 'live_wallpaper_processes', return_value=[entry]), \
             patch.object(m, 'unconfigured_swaybg', return_value=True), \
             patch.object(m, 'matches_wayland_session', return_value=True), \
             patch.object(m, 'proc_start', side_effect=lambda pid: '9' if pid == 6202 else '1'), \
             patch.object(m.shutil, 'which', return_value='/usr/bin/swaybg'), \
             patch.object(m.subprocess, 'Popen', return_value=fake) as start, \
             patch.object(m.os, 'kill') as kill, \
             patch.object(m.time, 'sleep'), \
             patch.dict(os.environ, WAYLAND_DISPLAY='wayland-9'), \
             patch.object(Path,'stat',stat_for_old), \
             patch.object(Path,'read_text',read_old_name):
            result = m.apply_swaybg(self.image)
        self.assertTrue(result['ok'])
        self.assertEqual(start.call_args.args[0], ['swaybg','-o','*','-i',str(self.image),'-m','fill'])
        kill.assert_called_once_with(6201, m.signal.SIGTERM)

    def test_nonbare_unmanaged_backend_requires_explicit_replace(self):
        m = self.m
        with patch.object(m, 'runtime_dir', return_value=self.homedir), \
             patch.object(m, 'live_wallpaper_processes', return_value=[{'pid':51,'name':'hyprpaper'}]), \
             patch.object(m, 'unconfigured_swaybg', return_value=False), \
             patch.object(m.shutil, 'which', return_value='/usr/bin/swaybg'), \
             patch.object(m.subprocess, 'Popen') as proc, \
             patch.dict(os.environ, WAYLAND_DISPLAY='wayland-9'):
            with self.assertRaisesRegex(RuntimeError, 'Another wallpaper backend'):
                m.apply_swaybg(self.image)
        proc.assert_not_called()

    def test_qml_startup_and_ui_commands(self):
        shell = (ROOT / 'shell.qml').read_text()
        ui = (ROOT / 'modules/settings/pages/SettingsAppearancePage.qml').read_text()
        self.assertIn('"--restore"', shell)
        self.assertIn('wallpaperStartup.exec(args)', shell)
        self.assertIn('"--remember"', ui)
        self.assertIn('"--configure-restore"', ui)
        self.assertIn('SettingsStore.wallpaperAutoRestore = outcome.auto_restore === true', ui)
        self.assertIn('Restore swaybg automatically after login', ui)

if __name__ == '__main__':
    unittest.main()
