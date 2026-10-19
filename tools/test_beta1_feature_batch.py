"""Offline regression tests: Beta1 sourced from the user's ZIP; no live OS mutations."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(filename, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / filename)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

calc = load('rusticq-calc.py', 'rusticq_calc_test')
cli = load('rusticq-cli.py', 'rusticq_cli_test')
watchdog = load('rusticq-watchdog.py', 'rusticq_watchdog_test')


class CalculatorTests(unittest.TestCase):
    def test_operators_and_scientific(self):
        for expr, result in [('2+2*3', '8'), ('(2+2)*3', '12'), ('sqrt(144)+8', '20'),
                             ('2^5', '32'), ('sin(pi/2)', '1'), ('log10(1000)', '3')]:
            self.assertEqual(calc.evaluate(expr), result)

    def test_expression_cannot_execute_python(self):
        for expr in ('__import__("os").system("echo hi")', '().__class__',
                     '[x for x in (1,2)]', 'open("/etc/passwd")', '2**100',
                     '1/0', '1e999', '2+'+'1'*190):
            with self.subTest(expr=expr), self.assertRaises((ValueError, SyntaxError)):
                calc.evaluate(expr)

    def test_result_out_of_bounds(self):
        for expr in ('10^13*100', 'sqrt(-1)', 'ln(0)'):
            with self.subTest(expr=expr), self.assertRaises(ValueError):
                calc.evaluate(expr)

    def test_launcher_integrates_without_app_command_eval(self):
        launcher = (ROOT / 'modules/main/MiniLauncher.qml').read_text()
        self.assertIn('readonly property bool calculatorMode:', launcher)
        self.assertIn('calcDebounce.restart()', launcher)
        self.assertIn('onExited: (code, status)', launcher)
        self.assertIn('onClicked: root.copyResult()', launcher)
        self.assertIn('Keys.onDownPressed:', launcher)  # old navigation preserved


class CLIAndServiceTests(unittest.TestCase):
    def test_watchdog_install_is_explicit_and_does_not_start_service(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaisesRegex(ValueError, 'confirmation'):
                watchdog.install(folder, '')
            status = watchdog.status(folder)
            self.assertFalse(status['installed'])
            result = watchdog.install(folder, 'INSTALL WATCHDOG')
            self.assertTrue(result['installed'])
            self.assertTrue(result['changed'])
            status = watchdog.status(folder)
            self.assertTrue(status['installed'])
            target = Path(folder) / '.config/systemd/user/rusticq.service'
            self.assertIn('Restart=on-failure', target.read_text())
            self.assertIn('StartLimitBurst=3', target.read_text())
            self.assertNotIn('ExecStartPre=sudo', target.read_text())
            self.assertFalse(any((Path(folder) / '.config/systemd/user').glob('*.wants/*')))
            self.assertFalse(watchdog.install(folder, 'INSTALL WATCHDOG')['changed'])

    def test_watchdog_preserves_custom_existing_unit(self):
        with tempfile.TemporaryDirectory() as folder:
            target = Path(folder) / '.config/systemd/user/rusticq.service'
            target.parent.mkdir(parents=True)
            target.write_text('my own unit')
            with self.assertRaisesRegex(ValueError, 'custom'):
                watchdog.install(folder, 'INSTALL WATCHDOG')
            self.assertEqual(target.read_text(), 'my own unit')

    def test_ipc_rejects_arbitrary_actions_before_spawn(self):
        with patch.object(cli, 'execute', return_value=subprocess.CompletedProcess([], 0, json.dumps({
            'actions': [{'key': 'launcher'}]}), '')) as proc:
            with self.assertRaisesRegex(ValueError, 'Unsupported IPC'):
                cli.ipc_action('some; sudo pacman -R foo')
            self.assertEqual(proc.call_count, 1)

    def test_cli_config_uses_locked_guard(self):
        with tempfile.TemporaryDirectory() as folder:
            project = Path(folder) / 'quickshell'
            (project / 'scripts').mkdir(parents=True)
            from shutil import copy2
            copy2(ROOT / 'scripts/rusticq-config-guard.py', project / 'scripts/rusticq-config-guard.py')
            (project / 'user-settings.json').write_text('{"barMode":"simple"}')
            with patch.object(cli, 'SCRIPT', project / 'scripts'), patch.dict('os.environ', {'XDG_STATE_HOME': str(Path(folder) / 'state')}):
                old = cli.config_action('status')
                self.assertEqual(old['settings']['status'], 'valid')
                snap = cli.config_action('backup')
                self.assertRegex(snap['id'], r'^\d{8}T\d{6}Z-')
                (project / 'user-settings.json').write_text('{"barMode":"compact"}')
                with self.assertRaises(RuntimeError):
                    cli.config_action('restore', snapshot_id=snap['id'], confirm='NO')
                restored = cli.config_action('restore', snapshot_id=snap['id'], confirm='RESTORE')
                self.assertEqual(restored['restored'], snap['id'])
                self.assertEqual(json.loads((project / 'user-settings.json').read_text())['barMode'], 'simple')

    def test_settings_integration_is_read_only_on_open(self):
        qml = (ROOT / 'modules/settings/pages/SettingsIntegrationPage.qml').read_text()
        self.assertIn('heading: "System Doctor & configuration recovery"', qml)
        self.assertIn('root.makeConfigBackup()', qml)
        self.assertIn('python3", doctorHelper, "status", "--json"', qml)
        self.assertIn('"backup", "--kind", "settings"', qml)
        self.assertIn('"ENABLE RUSTICQ"', qml)

    def test_installer_preserves_gui_invocation(self):
        script = (ROOT / 'scripts/install.sh').read_text()
        self.assertIn('"${1:-}" == "doctor"', script)
        self.assertIn('exec qs -p %q "$@"', script)
        subprocess.run(['bash', '-n', str(ROOT / 'scripts/install.sh')], check=True)
        result = subprocess.run(['bash', str(ROOT / 'scripts/install.sh'), '--dry-run'], capture_output=True, text=True, check=True)
        self.assertIn('DRY RUN', result.stdout)


if __name__ == '__main__':
    unittest.main()
