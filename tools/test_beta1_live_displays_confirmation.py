#!/usr/bin/env python3
"""Offline regression tests for Beta 1 confirmation floating + instant displays."""
from pathlib import Path
import importlib.util
import json
import tempfile
from unittest.mock import patch
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


DISPLAY = load_module(ROOT / 'scripts/rustiq-display.py', 'rusticq_live_display')
CONFIRM = load_module(ROOT / 'scripts/rustiq-confirmation-float.py', 'rusticq_confirmation')


def monitors():
    return [
        dict(name='eDP-1', width=1920, height=1080, x=0, y=0, scale=1,
             mode='1920x1080@60.00', refreshRate=60),
        dict(name='HDMI-A-1', width=1920, height=1080, x=1920, y=0, scale=1,
             mode='1920x1080@100.00', refreshRate=100),
    ]


class LiveTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.pending = Path(self.directory.name) / 'pending.json'
        replace = patch.object(DISPLAY, 'PENDING', self.pending)
        replace.start()
        self.addCleanup(replace.stop)

    def test_valid_layout(self):
        self.assertEqual(len(DISPLAY.validate(monitors())), 2)

    def test_overlap_rejected(self):
        draft = monitors()
        draft[1]['x'] = 800
        with self.assertRaisesRegex(ValueError, 'overlap'):
            DISPLAY.validate(draft)

    def test_live_keyword_then_readback(self):
        sample = monitors()
        with patch.object(DISPLAY, 'apply_with_keyword') as keyword, \
             patch.object(DISPLAY, 'readback', return_value={m['name']: m for m in sample}), \
             patch.object(DISPLAY.time, 'sleep'):
            method = DISPLAY.apply_live(sample)
            self.assertEqual(method, 'keyword')
            keyword.assert_called_once()

    def test_lua_fallback_when_keyword_is_rejected(self):
        sample = monitors()
        with patch.object(DISPLAY, 'apply_with_keyword', side_effect=RuntimeError('no legacy command')), \
             patch.object(DISPLAY, 'apply_with_eval') as fallback, \
             patch.object(DISPLAY, 'readback', return_value={m['name']: m for m in sample}), \
             patch.object(DISPLAY.time, 'sleep'):
            self.assertEqual(DISPLAY.apply_live(sample), 'lua')
            fallback.assert_called_once()

    def test_changed_display_creates_recovery_before_live_apply(self):
        before = {m['name']: dict(m) for m in monitors()}
        changed = monitors()
        changed[1]['x'] = 1960
        # Keep a gap between monitor edges for this test.
        with patch.object(DISPLAY, 'readback', return_value=before), \
             patch.object(DISPLAY, 'apply_live', return_value='keyword') as apply, \
             patch.object(DISPLAY, 'launch_watchdog') as watch, \
             patch.object(DISPLAY.sys, 'argv', ['display', 'apply']), \
             patch.object(DISPLAY.sys, 'stdin', __import__('io').StringIO(json.dumps(changed) + '\n')):
            result = DISPLAY.main()
        self.assertTrue(result['pending'])
        self.assertEqual(result['seconds'], 15)
        self.assertEqual(DISPLAY.pending_read()['baseline'], DISPLAY.validate(DISPLAY.from_active(before)))
        watch.assert_called_once()
        apply.assert_called_once()

    def test_stdin_newline_is_required_for_process_protocol(self):
        with patch.object(DISPLAY.sys, 'argv', ['display', 'dry-run']), \
             patch.object(DISPLAY.sys, 'stdin', __import__('io').StringIO(json.dumps(monitors()))):
            with self.assertRaisesRegex(ValueError, 'incomplete'):
                DISPLAY.main()

    def test_pending_token_is_private_and_atomic(self):
        DISPLAY.pending_write(dict(token='a' * 32, baseline=monitors()))
        self.assertEqual(DISPLAY.pending_read()['token'], 'a' * 32)
        self.assertEqual(self.pending.stat().st_mode & 0o777, 0o600)
        DISPLAY.pending_clear('b' * 32)
        self.assertTrue(self.pending.exists())
        DISPLAY.pending_clear('a' * 32)
        self.assertFalse(self.pending.exists())

    def test_watch_reverts_only_matching_token(self):
        DISPLAY.pending_write(dict(token='a' * 32, baseline=monitors()))
        with patch.object(DISPLAY.time, 'sleep'), patch.object(DISPLAY, 'rollback') as undo:
            DISPLAY.watchdog('b' * 32)
            undo.assert_not_called()
            DISPLAY.watchdog('a' * 32)
            undo.assert_called_once()
            self.assertFalse(self.pending.exists())

    def test_keep_does_not_revert(self):
        DISPLAY.pending_write(dict(token='a' * 32, baseline=monitors()))
        self.assertFalse(DISPLAY.main.__name__ == 'wrong')
        with patch.object(DISPLAY.sys, 'argv', ['display', 'keep']):
            result = DISPLAY.main()
        self.assertTrue(result['ok'])
        self.assertFalse(self.pending.exists())

    def test_confirmation_targets_settings_workspace(self):
        settings = dict(title=CONFIRM.SETTINGS_TITLE, address='0xabcd1111',
                        workspace=dict(id=2), floating=True)
        confirm = dict(title=CONFIRM.CONFIRM_TITLE, address='0xabcd2222',
                       workspace=dict(id=1), floating=True, size=[510, 360])
        moved = dict(confirm, workspace=dict(id=2))
        with patch.object(CONFIRM, 'dispatch_lua', return_value=True) as dispatch, \
             patch.object(CONFIRM, 'get_clients', return_value=[settings, moved]), \
             patch.object(CONFIRM.time, 'sleep'):
            self.assertTrue(CONFIRM.arrange(settings, confirm))
        commands = ' '.join(c.args[0] for c in dispatch.call_args_list)
        self.assertIn('workspace = 2', commands)
        self.assertIn('follow = false', commands)
        self.assertIn('address:0xabcd2222', commands)

    def test_confirmation_filters_title_and_address(self):
        clients = [dict(title=CONFIRM.CONFIRM_TITLE, address='not-a-client'),
                   dict(title=CONFIRM.CONFIRM_TITLE, address='0xabcd2222')]
        self.assertEqual(CONFIRM.find_client(clients, CONFIRM.CONFIRM_TITLE)['address'], '0xabcd2222')

    def test_qml_live_and_floating(self):
        qml = (ROOT / 'modules/bar/BarMonitors.qml').read_text()
        modal = (ROOT / 'modules/main/PackageConfirmationWindow.qml').read_text()
        self.assertIn('scheduleLive()', qml)
        self.assertIn('root.run("keep")', qml)
        self.assertIn('root.run("revert")', qml)
        self.assertIn('FloatingWindow {', modal)
        self.assertNotIn('PanelWindow {', modal)
        self.assertNotIn('WlrLayer.Overlay', modal)


if __name__ == '__main__':
    unittest.main()
