#!/usr/bin/env python3
"""Offline assertions: native Omarchy ASCII screensaver and aligned power overlay."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('rusticq_power_test', ROOT/'scripts/rusticq-power-action.py')
PWR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PWR)


class PowerMenuAlignmentTests(unittest.TestCase):
    def test_screensaver_invokes_native_omarchy_with_force(self):
        with patch.object(PWR.shutil, 'which', return_value='/usr/bin/omarchy-launch-screensaver'):
            self.assertEqual(PWR.action_command('screensaver'), ['omarchy-launch-screensaver', 'force'])
        with patch.object(PWR.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'Omarchy screensaver unavailable'):
                PWR.action_command('screensaver')

    def test_overlay_closes_before_delayed_launch(self):
        with patch.object(PWR.shutil, 'which', return_value='/usr/bin/omarchy-launch-screensaver'), \
             patch.object(PWR.subprocess, 'Popen') as proc:
            reply = PWR.run('screensaver')
        self.assertTrue(reply['ok'])
        argv = proc.call_args.args[0]
        self.assertEqual(argv[0], sys.executable)
        self.assertTrue(str(argv[1]).endswith('/scripts/rusticq-power-action.py'))
        self.assertEqual(argv[2], '--start-omarchy-screensaver')
        self.assertTrue(proc.call_args.kwargs['start_new_session'])

    def test_delayed_helper_opens_actual_native_screensaver(self):
        with patch.object(PWR.time, 'sleep') as sleep, \
             patch.object(PWR.shutil, 'which', return_value='/usr/bin/omarchy-launch-screensaver'), \
             patch.object(PWR.subprocess, 'Popen') as proc:
            PWR.start_native_screensaver()
        self.assertGreaterEqual(sleep.call_args.args[0], .7)
        self.assertEqual(proc.call_args.args[0], ['omarchy-launch-screensaver', 'force'])
        self.assertTrue(proc.call_args.kwargs['start_new_session'])

    def test_session_action_commands(self):
        with patch.object(PWR.shutil, 'which', side_effect=lambda name: None if name == 'uwsm' else '/usr/bin/fake'):
            self.assertTrue(PWR.action_command('lock')[1].endswith('/scripts/rusticq-native-lock.py'))
            self.assertEqual(PWR.action_command('suspend'), ['systemctl', 'suspend'])
            self.assertEqual(PWR.action_command('reboot'), ['systemctl', 'reboot'])
            self.assertEqual(PWR.action_command('shutdown'), ['systemctl', 'poweroff'])
            self.assertEqual(PWR.action_command('logout'), ['hyprctl', 'dispatch', 'hl.dsp.exit()'])

    def test_menu_uses_consistent_columns_and_no_x(self):
        qml = (ROOT/'modules/power/PowerMenu.qml').read_text()
        self.assertIn('PanelWindow {', qml)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay', qml)
        self.assertIn('anchors.centerIn: parent', qml)
        self.assertIn('iconColumnWidth: 40', qml)
        self.assertIn('x: root.textColumnX', qml)
        self.assertIn('width: root.shortcutColumnWidth', qml)
        self.assertIn('horizontalAlignment: Text.AlignRight', qml)
        self.assertIn('radius: Theme.sectionRadius', qml)
        self.assertIn('border.width: 1', qml)
        self.assertNotIn('text: "×"', qml)
        self.assertIn('Qt.Key_Escape', qml)
        self.assertIn('Omarchy animated ASCII screensaver', qml)

if __name__ == '__main__':
    unittest.main()
