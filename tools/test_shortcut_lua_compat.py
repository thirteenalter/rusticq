#!/usr/bin/env python3
"""Regression: Omarchy Quattro builds where o.rebind is nil.

Uses isolated fake homes and mocked compositor; never touches host Hyprland.
"""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/rustiq-desktop-integration.py'


def load_module():
    spec = importlib.util.spec_from_file_location('rusticq_shortcut_compat_test', SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class LuaCompatTests(unittest.TestCase):
    def test_emits_unbind_before_bind_never_rebind(self):
        m = load_module()
        with tempfile.TemporaryDirectory() as d:
            with patch.object(m, 'ROOT', Path(d)), patch.object(m, 'META', Path(d) / 'not-installed'), patch.object(m, 'REMAPS', Path(d) / 'none'):
                content = 'o.bind("SUPER + ESCAPE", "Original recovery", "recovery")\n'
                changed = m.write_shortcuts({'power': 'SUPER + ESCAPE'}, content, {})
                self.assertTrue(changed.startswith(content.rstrip() + '\n'))
                self.assertIn('hl.unbind("SUPER + ESCAPE")', changed)
                self.assertIn('o.bind("SUPER + ESCAPE", "RusticQ Power menu",', changed)
                self.assertLess(changed.index('hl.unbind("SUPER + ESCAPE")'), changed.index('o.bind("SUPER + ESCAPE", "RusticQ'))
                self.assertNotIn('o.rebind(', changed)
                self.assertEqual(m.write_shortcuts({}, changed, {}), content)

    def test_remap_unbinds_old_and_destination(self):
        m = load_module()
        remap = {'sample': {'from': 'SUPER + A', 'to': 'SUPER + B', 'label': 'App', 'command': 'foot'}}
        q = m.write_shortcuts({}, '-- original\n', remap)
        self.assertIn('hl.unbind("SUPER + A")', q)
        self.assertIn('hl.unbind("SUPER + B")', q)
        self.assertIn('o.bind("SUPER + B", "App", "foot")', q)
        self.assertNotIn('o.rebind(', q)

    def test_rejected_reload_restores_old_file_and_reloads(self):
        m = load_module()
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'bindings.lua'
            old = 'o.bind("SUPER + X", "Original", "command")\n'
            path.write_text('BROKEN')
            reloads = []
            def fake_reload():
                reloads.append(path.read_text())
                if len(reloads) == 1:
                    raise ValueError('Hyprland reports configuration errors: bad helper')
                return 'Valid after rollback'
            with patch.object(m, 'BINDINGS', path), patch.object(m, 'run_hypr_reload', side_effect=fake_reload):
                with self.assertRaisesRegex(ValueError, 'original bindings restored and Hyprland reloaded'):
                    try:
                        m.run_hypr_reload()
                    except ValueError as error:
                        m.restore_bindings_after_rejected_reload(old, error)
            self.assertEqual(path.read_text(), old)
            self.assertEqual(len(reloads), 2)

    def test_failed_recovery_does_not_claim_success(self):
        m = load_module()
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'bindings.lua'
            path.write_text('BAD')
            with patch.object(m, 'BINDINGS', path), patch.object(m, 'run_hypr_reload', side_effect=ValueError('still invalid')):
                with self.assertRaisesRegex(ValueError, 'reload/validation failed'):
                    m.restore_bindings_after_rejected_reload('ORIGINAL\n', ValueError('initial error'))
            self.assertEqual(path.read_text(), 'ORIGINAL\n')

    def test_existing_legacy_managed_block_migrates_on_next_apply(self):
        m = load_module()
        original = 'o.bind("SUPER + A", "App", "true")\n'
        legacy = m.append_block(original, 'o.rebind("SUPER + B", "RusticQ Settings", "some old command")')
        updated = m.write_shortcuts({'settings': 'SUPER + B', 'power':'SUPER + ESCAPE'}, legacy, {})
        self.assertNotIn('o.rebind(', updated)
        self.assertEqual(updated.count(m.START), 1)
        self.assertEqual(updated.count(m.END), 1)
        self.assertEqual(m.write_shortcuts({}, updated, {}), original)


if __name__ == '__main__':
    unittest.main()
