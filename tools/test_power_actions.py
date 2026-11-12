#!/usr/bin/env python3
"""Power command regressions; all subprocesses are mocked, never end a session."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('power_actions', ROOT / 'scripts/rusticq-power-action.py')
POWER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(POWER)


def reply(code=0, stdout='', stderr=''):
    return subprocess.CompletedProcess([], code, stdout, stderr)


class PowerActionTests(unittest.TestCase):
    def setUp(self):
        self.installed = {'systemctl', 'hyprctl'}
        which = patch.object(POWER.shutil, 'which', side_effect=lambda name:
                             '/usr/bin/' + name if name in self.installed else None)
        which.start()
        self.addCleanup(which.stop)
        run = patch.object(POWER.subprocess, 'run', return_value=reply())
        self.command = run.start()
        self.addCleanup(run.stop)
        spawn = patch.object(POWER.subprocess, 'Popen', side_effect=AssertionError('Unexpected detached action'))
        spawn.start()
        self.addCleanup(spawn.stop)

    def test_system_power_commands(self):
        for action, verb in [('suspend', 'suspend'), ('reboot', 'reboot'), ('shutdown', 'poweroff')]:
            with self.subTest(action=action):
                self.command.reset_mock()
                self.assertTrue(POWER.run(action)['ok'])
                self.command.assert_called_once_with(
                    ['systemctl', verb], capture_output=True, text=True, timeout=12,
                    stdin=subprocess.DEVNULL, check=False)

    def test_missing_systemctl_rejected_before_launch(self):
        self.installed = {'loginctl'}
        for action in ('suspend', 'reboot', 'shutdown'):
            with self.subTest(action=action), self.assertRaisesRegex(RuntimeError, 'systemctl is required'):
                POWER.run(action)
        self.command.assert_not_called()

    def test_power_service_rejections_are_not_retried(self):
        for action in ('suspend', 'reboot', 'shutdown'):
            with self.subTest(action=action):
                self.command.reset_mock()
                self.command.return_value = reply(1, stderr='Operation inhibited')
                self.assertEqual(POWER.run(action), {'ok': False, 'message': 'Operation inhibited'})
                self.command.assert_called_once()

    def test_active_uwsm_owns_logout(self):
        self.installed.add('uwsm')
        self.assertTrue(POWER.run('logout')['ok'])
        self.assertEqual([call.args[0] for call in self.command.call_args_list],
                         [['uwsm', 'check', 'is-active', 'Hyprland'], ['uwsm', 'stop']])

    def test_installed_but_inactive_uwsm_uses_lua(self):
        self.installed.add('uwsm')
        self.command.side_effect = [reply(1), reply(stdout='ok\n')]
        self.assertTrue(POWER.run('logout')['ok'])
        self.assertEqual(self.command.call_args.args[0], ['hyprctl', 'dispatch', 'hl.dsp.exit()'])

    def test_uwsm_stop_failure_does_not_force_compositor_exit(self):
        self.installed.add('uwsm')
        self.command.side_effect = [reply(), reply(1, stderr='Session stop failed')]
        self.assertEqual(POWER.run('logout'), {'ok': False, 'message': 'Session stop failed'})
        self.assertEqual(self.command.call_count, 2)

    def test_lua_logout(self):
        self.command.return_value = reply(stdout='ok\n')
        self.assertTrue(POWER.run('logout')['ok'])
        self.command.assert_called_once()
        self.assertEqual(self.command.call_args.args[0], ['hyprctl', 'dispatch', 'hl.dsp.exit()'])

    def test_legacy_logout_only_after_invalid_dispatcher(self):
        for code in (0, 1):
            with self.subTest(code=code):
                self.command.reset_mock()
                self.command.side_effect = [reply(code, 'Invalid dispatcher\n'), reply(stdout='ok\n')]
                self.assertTrue(POWER.run('logout')['ok'])
                self.assertEqual([call.args[0] for call in self.command.call_args_list],
                                 [['hyprctl', 'dispatch', 'hl.dsp.exit()'], ['hyprctl', 'dispatch', 'exit']])

    def test_hyprland_errors_remain_visible_even_with_zero_exit_code(self):
        for code, message in ((0, 'error: hl.dispatch: expected a dispatcher'),
                              (1, 'Could not connect to socket'), (0, '')):
            with self.subTest(code=code, message=message):
                self.command.reset_mock()
                self.command.return_value = reply(code, message)
                result = POWER.run('logout')
                self.assertFalse(result['ok'])
                self.assertTrue(result['message'])
                self.command.assert_called_once()

    def test_failed_legacy_fallback_stays_an_error(self):
        self.command.side_effect = [reply(1, 'Invalid dispatcher'), reply(0, 'error: exit failed')]
        self.assertFalse(POWER.run('logout')['ok'])
        self.assertEqual(self.command.call_count, 2)

    def test_timeout_never_retries_logout(self):
        self.command.side_effect = subprocess.TimeoutExpired('hyprctl', 12)
        with self.assertRaises(subprocess.TimeoutExpired):
            POWER.run('logout')
        self.command.assert_called_once()

    def test_missing_logout_backend(self):
        self.installed.clear()
        with self.assertRaisesRegex(RuntimeError, 'hyprctl is required'):
            POWER.run('logout')
        self.command.assert_not_called()

    def test_invalid_action_never_launches(self):
        with self.assertRaises(ValueError):
            POWER.run('reboot; poweroff')
        self.command.assert_not_called()


if __name__ == '__main__':
    unittest.main()
