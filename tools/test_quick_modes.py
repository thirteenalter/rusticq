#!/usr/bin/env python3
"""Offline Night Light contracts, including startup races and exact readback."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('quick_modes', Path(__file__).resolve().parents[1] / 'scripts/quick_modes.py')
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ModesTests(unittest.TestCase):
    def setUp(self):
        self.temp = 6500
        self.writes = []
        self.respond = True
        for obj, name, options in [
            (mod, 'run', {'side_effect': self.run_command}),
            (mod.shutil, 'which', {'return_value': '/test/bin/tool'}),
            (mod.time, 'sleep', {}),
            (mod.subprocess, 'Popen', {'side_effect': self.start}),
        ]:
            patcher = patch.object(obj, name, **options)
            patcher.start()
            self.addCleanup(patcher.stop)

    def start(self, command, **kwargs):
        self.writes.append(command)
        self.temp = int(command[-1])

    def run_command(self, args, timeout=5):
        self.assertEqual(args[:3], ['hyprctl', 'hyprsunset', 'temperature'])
        if self.temp is None:
            raise RuntimeError('hyprsunset not running')
        if len(args) == 4:
            self.writes.append(args)
            if self.respond:
                self.temp = int(args[3])
        return str(self.temp)

    def test_probe_never_starts_daemon(self):
        for temp in (6500, 4000, None):
            self.temp = temp
            state = mod.probe('night')
            self.assertTrue(state['available'])
            self.assertEqual(state['active'], temp is not None and temp < 6500)
        self.assertEqual(self.writes, [])

    def test_full_temperature_range_and_idempotence(self):
        for value in (2000, 3400, 6000):
            mod.set_mode('night', True, value)
            self.assertEqual(self.temp, value)
            count = len(self.writes)
            mod.set_mode('night', True, value)
            self.assertEqual(len(self.writes), count)
        mod.set_mode('night', False)
        self.assertEqual(self.temp, 6500)

    def test_start_only_on_enable_and_use_selected_temperature(self):
        self.temp = None
        mod.set_mode('night', False, 3000)
        self.assertEqual(self.writes, [])
        mod.set_mode('night', True, 3000)
        self.assertIn(['uwsm-app', '--', 'hyprsunset', '--temperature', '3000'], self.writes)
        self.assertEqual(self.temp, 3000)

    def test_startup_temperature_overwrite_is_retried(self):
        self.temp = None
        original = self.run_command
        overwritten = [False]
        def command(args, timeout=5):
            value = original(args, timeout)
            if len(args) == 4 and not overwritten[0]:
                self.temp = 6000
                overwritten[0] = True
            return value
        with patch.object(mod, 'run', side_effect=command):
            mod.set_mode('night', True, 2700)
        self.assertEqual(self.temp, 2700)
        self.assertGreaterEqual(len(self.writes), 3)

    def test_failed_apply_requires_exact_readback(self):
        self.respond = False
        with self.assertRaises(RuntimeError):
            mod.set_mode('night', True, 3000)
        self.temp = 4000
        with self.assertRaises(RuntimeError):
            mod.set_mode('night', True, 3000)

    def test_dependencies_and_invalid_response(self):
        with patch.object(mod.shutil, 'which', return_value=None):
            self.assertFalse(mod.probe('night')['available'])
            with self.assertRaises(RuntimeError):
                mod.set_mode('night', True)
        with patch.object(mod, 'run', return_value='invalid'):
            with self.assertRaises(RuntimeError):
                mod.temperature()
        with patch.object(mod, 'run', side_effect=subprocess.TimeoutExpired('hyprctl', 5)):
            self.assertIsNone(mod.probe('night')['temperature'])

    def test_rejects_unsupported_values_without_writes(self):
        for key, enabled, temperature in [('silent', True, 4000), ('night', 'on', 4000),
                                         ('night', True, 1999), ('night', True, 6001),
                                         ('night', True, True), ('night', True, 3000.5)]:
            with self.assertRaises(ValueError):
                mod.set_mode(key, enabled, temperature)
        self.assertEqual(self.writes, [])


if __name__ == '__main__':
    unittest.main()
