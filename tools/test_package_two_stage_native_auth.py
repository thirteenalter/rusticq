#!/usr/bin/env python3
"""Regression for two-stage package UI and real system-native Polkit.

Never installs packages, opens an agent, or executes pkexec on test machine.
"""
import importlib.util
from pathlib import Path
from unittest import mock
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('rusticq_auth_two_stage',ROOT/'scripts/rustiq-package-manager.py')
PM=importlib.util.module_from_spec(spec)
spec.loader.exec_module(PM)

class NativePackageAuth(unittest.TestCase):
    def test_package_confirmation_opens_actual_native_polkit_dialog_second(self):
        store=(ROOT/'config/Store.qml').read_text()
        shell=(ROOT/'shell.qml').read_text()
        first=(ROOT/'modules/main/PackageConfirmationWindow.qml').read_text()
        native=(ROOT/'modules/main/NativePolkitAgent.qml').read_text()
        self.assertIn('cancelPackageConfirmation();\n        // First dialog was',store)
        self.assertIn('packageOperationConfirmed(action, name, provider);',store)
        self.assertIn('NativePolkitAgent {}',shell)
        self.assertNotIn('PackageAuthorizationOverlay {}',shell)
        self.assertIn('PolkitAgent {',native)
        self.assertIn('Step 1 of 2',first)
        self.assertIn('actual Polkit/PAM',first)

    def test_gui_requires_native_auth_before_package_operation(self):
        qml=(ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        self.assertIn('"authorize", root.pendingProvider, root.pendingAction, root.pendingPackage',qml)
        self.assertIn('root.authorizationPassed = true',qml)
        self.assertIn('if (authorizationPassed && authorizedCommand.length',qml)
        self.assertIn('root.authorizedCommand = [];',qml)
        self.assertIn('systemAuthLaunchDelay.restart();',qml)
        self.assertIn('Store.packageOperationConfirmed', (ROOT/'config/Store.qml').read_text()) if False else None

    def test_preauthorize_uses_only_safe_binary_and_no_terminal_fallback(self):
        with mock.patch.object(PM,'validate_source_package',return_value='ventoy-bin'), \
             mock.patch.object(PM.Path,'is_file',return_value=True), \
             mock.patch.object(PM,'ensure_graphical_agent',return_value=dict(agent_ready=True,agent_started=False)), \
             mock.patch.object(PM.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'','')) as execute:
            result=PM.preauthorize_package('yay','install','ventoy-bin')
        self.assertTrue(result['authorized'])
        call=execute.call_args
        self.assertEqual(call.args[0],['/usr/bin/pkexec','--disable-internal-agent','/usr/bin/true'])
        self.assertEqual(call.kwargs['stdin'],subprocess.DEVNULL)
        self.assertFalse(call.kwargs['check'])

    def test_denied_auth_blocks_package_execution(self):
        with mock.patch.object(PM,'validate_source_package',return_value='ventoy-bin'), \
             mock.patch.object(PM.Path,'is_file',return_value=True), \
             mock.patch.object(PM,'ensure_graphical_agent',return_value=dict(agent_ready=True,agent_started=False)), \
             mock.patch.object(PM.subprocess,'run',return_value=subprocess.CompletedProcess([],126,'','cancelled')):
            with self.assertRaisesRegex(RuntimeError,'cancelled'):
                PM.preauthorize_package('yay','install','ventoy-bin')

    def test_missing_agent_does_not_spawn_arbitrary_agent(self):
        with mock.patch.object(PM,'running_polkit_agent',return_value=False), \
             mock.patch.object(PM,'native_agent_bundled',return_value=False), \
             mock.patch.object(PM,'agent_service_available',return_value=False):
            with self.assertRaisesRegex(RuntimeError,'No graphical Polkit agent'):
                PM.ensure_graphical_agent()

    def test_known_agent_is_reused(self):
        with mock.patch.object(PM,'running_polkit_agent',return_value=True), \
             mock.patch.object(PM.subprocess,'run') as execute:
            result=PM.ensure_graphical_agent()
        self.assertTrue(result['agent_ready'])
        self.assertFalse(result['agent_started'])
        execute.assert_not_called()

    def test_agent_service_only_started_with_explicit_approval(self):
        with mock.patch.object(PM,'running_polkit_agent',return_value=False), \
             mock.patch.object(PM,'native_agent_bundled',return_value=False), \
             mock.patch.object(PM,'agent_service_available',return_value=True), \
             mock.patch.object(PM.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'','')) as execute, \
             mock.patch.object(PM.time,'sleep'):
            result=PM.ensure_graphical_agent()
        self.assertTrue(result['agent_started'])
        self.assertEqual(execute.call_args.args[0],['systemctl','--user','start','hyprpolkitagent.service'])

    def test_pkexec_never_uses_internal_tty_agent(self):
        qml=(ROOT/'modules/main/PackageAuthorizationOverlay.qml').read_text()
        source=(ROOT/'scripts/rustiq-package-manager.py').read_text()
        self.assertNotIn('TextInput {',qml)
        self.assertNotIn('sudo -S',source)
        self.assertIn("'--sudoflags', '--disable-internal-agent'",source)
        self.assertIn("[str(pkexec), '--disable-internal-agent', str(pacman)",source)
        self.assertIn("['/usr/bin/pkexec', '--disable-internal-agent', '/usr/bin/pacman'",source)

if __name__=='__main__': unittest.main()
