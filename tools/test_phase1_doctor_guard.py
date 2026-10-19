"""Offline end-to-end tests for read-only doctor + explicit config recovery.

No actual Hyprland, user config, pacman, or system service is mutated.
"""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]


def load(module_name, filename):
    spec = importlib.util.spec_from_file_location(module_name, PROJECT / 'scripts' / filename)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


guard = load('rusticq_config_guard', 'rusticq-config-guard.py')
doctor = load('rusticq_doctor', 'rusticq-doctor.py')


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = Path(self.tmp.name)
        self.project = base / 'project'
        self.project.mkdir()
        self.config = self.project / 'user-settings.json'
        self.config.write_text('{"barMode":"compact","showWeather":true}\n')
        self.guard = guard.Guard(self.project, base / 'state')

    def test_immutable_backup_and_restoration(self):
        old = self.config.read_bytes()
        created = self.guard.snapshot('settings')
        self.assertEqual(len(self.guard.versions('settings')), 1)
        self.config.write_text('{"barMode":"simple"}')
        with self.assertRaisesRegex(ValueError, 'confirmation'):
            self.guard.restore('settings', created['id'], '')
        self.assertEqual(self.config.read_text(), '{"barMode":"simple"}')
        result = self.guard.restore('settings', created['id'], 'RESTORE')
        self.assertEqual(result['restored'], created['id'])
        self.assertEqual(self.config.read_bytes(), old)
        self.assertEqual(len(self.guard.versions('settings')), 2)
        file = self.guard.target_dir('settings') / (created['id'] + '.json')
        self.assertEqual(file.stat().st_mode & 0o777, 0o600)

    def test_invalid_current_remains_recoverable(self):
        snap = self.guard.snapshot('settings')
        self.config.write_text('not a json object')
        self.assertEqual(self.guard.status()['settings']['status'], 'invalid')
        self.guard.restore('settings', snap['id'], 'RESTORE')
        self.assertEqual(self.guard.status()['settings']['status'], 'valid')
        self.assertTrue(any('not a json' in p.read_text() for p in self.guard.target_dir('settings').glob('*.json')))

    def test_no_symlinks_or_path_traversal(self):
        snap = self.guard.snapshot('settings')
        with self.assertRaisesRegex(ValueError, 'identifier'):
            self.guard.restore('settings', '../secrets', 'RESTORE')
        actual = self.config
        actual.unlink()
        actual.symlink_to(self.project / 'other.json')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.guard.restore('settings', snap['id'], 'RESTORE')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.guard.snapshot('settings')

    def test_invalid_backup_refused(self):
        with self.assertRaises(ValueError):
            guard.validate_json(b'[true]')
        with self.assertRaises(ValueError):
            guard.validate_json(b'{broken json}')
        with self.assertRaises(ValueError):
            guard.validate_json(b'{' + b'a' * 2_000_001 + b'}')

    def test_usage_separate(self):
        (self.project / 'app-usage.json').write_text('{"Firefox":{"count":3}}')
        version = self.guard.snapshot('usage')
        self.assertEqual(self.guard.status()['usage']['snapshots'], 1)
        self.assertEqual(self.guard.versions('settings'), [])
        self.assertTrue(version['id'])


class DoctorTests(unittest.TestCase):
    def test_doctor_no_live_desktop_is_read_only(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'shell.qml').write_text('ShellRoot {}')
            (root / 'config').mkdir()
            (root / 'config/SettingsStore.qml').write_text('Singleton {}')
            (root / 'user-settings.json').write_text('{}')
            with patch.object(doctor.shutil, 'which', return_value=None):
                with patch.dict(doctor.os.environ, {'WAYLAND_DISPLAY': ''}):
                    results = doctor.doctor(root)
            self.assertEqual(results['mode'], 'read-only')
            self.assertIn('skipped' if False else 'skip', results['totals'])
            ids = {r['id']: r for r in results['checks']}
            self.assertEqual(ids['source.shell.qml']['state'], 'ok')
            self.assertEqual(ids['config.user-settings.json']['state'], 'ok')
            self.assertEqual(ids['hyprland.monitors']['state'], 'skip')
            self.assertFalse((root / 'app-usage.json').exists())

    def test_doctor_malformed_config_warns(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'user-settings.json').write_text('{oops')
            with patch.object(doctor.shutil, 'which', return_value=None):
                result = doctor.doctor(root)
            bad = next(c for c in result['checks'] if c['id'] == 'config.user-settings.json')
            self.assertEqual(bad['state'], 'warn')
            self.assertIn('config-guard', bad['suggestion'])


if __name__ == '__main__':
    unittest.main()
