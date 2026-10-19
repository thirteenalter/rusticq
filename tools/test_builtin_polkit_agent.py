#!/usr/bin/env python3
"""Regression contracts: real PolicyKit agent in RusticQ, not decorative UI.

The tests never request elevation or store secrets; actual Polkit/PAM needs
Wayland runtime verification on a user system.
"""
from pathlib import Path
import importlib.util
from unittest import mock
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/rustiq-package-manager.py'
spec = importlib.util.spec_from_file_location('test_rusticq_polkit', SCRIPT)
pm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pm)

class NativePolkit(unittest.TestCase):
    def test_shell_replaces_omarchy_polkit_with_native_agent(self):
        shell = (ROOT / 'shell.qml').read_text()
        agent = (ROOT / 'modules/main/NativePolkitAgent.qml').read_text()
        self.assertEqual(shell.count('NativePolkitAgent {}'), 1)
        self.assertIn('import Quickshell.Services.Polkit', agent)
        self.assertIn('PolkitAgent {', agent)
        self.assertIn('visible: root.activeRequest', agent)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay', agent)
        self.assertIn('function sendResponse()', agent)
        self.assertIn('root.flow.submit(answer);', agent)
        self.assertIn('root.flow.cancelAuthenticationRequest()', agent)
        self.assertIn('echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password', agent)
        self.assertIn('root.flow.isResponseRequired', agent)
        self.assertIn('secretField.clear()', agent)
        self.assertIn('root.flow.supplementaryMessage', agent)
        self.assertNotIn('Quickshell.execDetached', agent)
        self.assertNotIn('sudo -S', agent)

    def test_probe_does_not_claim_native_registration(self):
        self.assertTrue(pm.native_agent_bundled())
        with mock.patch.object(pm, 'running_polkit_agent', return_value=False), \
             mock.patch.object(pm, 'agent_service_available', return_value=False):
            result = pm.ensure_graphical_agent()
        self.assertEqual(result['agent'], 'rusticq-native')
        self.assertFalse(result['agent_ready'])
        self.assertFalse(result['agent_started'])

    def test_native_agent_does_not_attempt_duplicate_service(self):
        with mock.patch.object(pm, 'running_polkit_agent', return_value=False), \
             mock.patch.object(pm, 'agent_service_available', return_value=True), \
             mock.patch.object(pm.subprocess, 'run') as runner:
            result = pm.ensure_graphical_agent()
        self.assertEqual(result['agent'], 'rusticq-native')
        runner.assert_not_called()

    def test_explicit_pkexec_response_required_before_yay(self):
        with mock.patch.object(pm, 'validate_source_package', return_value='ventoy-bin'), \
             mock.patch.object(pm.Path, 'is_file', return_value=True), \
             mock.patch.object(pm, 'ensure_graphical_agent', return_value={'agent_started':False,'agent':'rusticq-native'}), \
             mock.patch.object(pm.subprocess, 'run', return_value=subprocess.CompletedProcess([], 127, '', 'no agent registered')):
            with self.assertRaisesRegex(RuntimeError, 'no agent registered'):
                # Generic, accurate diagnosis; no package commands run.
                pm.preauthorize_package('yay', 'install', 'ventoy-bin')

    def test_ui_explains_native_backend_not_missing_standalone_process(self):
        page = (ROOT / 'modules/settings/pages/SettingsInfoPage.qml').read_text()
        store = (ROOT / 'config/Store.qml').read_text()
        overlay = (ROOT / 'modules/main/PackageAuthorizationOverlay.qml').read_text()
        self.assertIn('data.native_agent_bundled', page)
        self.assertIn('packageAuthNativeBundled: false', store)
        self.assertIn('Store.packageAuthNativeBundled', overlay)
        self.assertIn('native Quickshell Polkit agent', overlay)
        self.assertIn('"authorize", root.pendingProvider', page)
        self.assertIn('if (authorizationPassed && authorizedCommand.length', page)

    def test_prohibit_untrusted_credential_paths(self):
        pm_source = SCRIPT.read_text()
        agent = (ROOT / 'modules/main/NativePolkitAgent.qml').read_text()
        self.assertNotIn('sudo -S', pm_source)
        self.assertNotIn('echo $PASSWORD', agent)
        self.assertNotIn('Store.password', agent)
        self.assertNotIn('console.log(answer)', agent)
        self.assertNotIn('Quickshell.Io', agent)

if __name__ == '__main__': unittest.main()
