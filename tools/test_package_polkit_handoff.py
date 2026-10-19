#!/usr/bin/env python3
"""Regression: real Polkit handoff in a Wayland authorization layer.

No privileged binaries or package mutations are executed during tests.
"""
from pathlib import Path
import importlib.util
import unittest
from unittest import mock
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/rustiq-package-manager.py'
spec = importlib.util.spec_from_file_location('rusticq_package_auth_test', SCRIPT)
PKG = importlib.util.module_from_spec(spec)
spec.loader.exec_module(PKG)

class PolkitHandoffTests(unittest.TestCase):
    def test_yay_uses_supported_cli_and_unprivileged_build(self):
        calls=[]
        def output(cmd, timeout=20):
            calls.append(cmd)
            if cmd[:3] == ['pacman', '-Qq', 'ventoy-bin']:
                return SimpleNamespace(returncode=0,stdout='ventoy-bin',stderr='')
            return SimpleNamespace(returncode=0,stdout='ok',stderr='')
        with mock.patch.object(PKG.shutil,'which', return_value='/usr/bin/yay'), \
             mock.patch.object(PKG.os,'geteuid', return_value=1000), \
             mock.patch.object(PKG,'lookup_aur_package',return_value=True), \
             mock.patch.object(PKG.Path,'is_file', return_value=True), \
             mock.patch.object(PKG,'cmd_output',side_effect=output):
            result = PKG.source_transaction('yay','install','ventoy-bin')
        self.assertTrue(result['ok'], result)
        cmd=calls[0]
        self.assertEqual(cmd[0:2],['yay','-S'])
        self.assertNotIn('--nosudoloop',cmd)
        self.assertNotIn('--nocolor',cmd)
        self.assertIn('--sudo',cmd)
        self.assertEqual(cmd[cmd.index('--sudo')+1], '/usr/bin/pkexec')
        self.assertNotEqual(cmd[0], '/usr/bin/pkexec')

    def test_invalid_actions_rejected(self):
        with self.assertRaises(ValueError):
            PKG.source_transaction('yay','execute-shell','ventoy-bin')
        with self.assertRaises(ValueError):
            PKG.source_transaction('yay','install','; rm -rf /')

    def test_store_adds_real_second_consent(self):
        store=(ROOT/'config/Store.qml').read_text()
        self.assertIn('property bool packageAuthVisible: false',store)
        self.assertIn('packageOperationConfirmed(action, name, provider)',store)
        self.assertIn('function cancelPackageAuthorization()',store)
        self.assertIn('function approvePackageAuthorization()',store)
        self.assertIn('packageOperationConfirmed(action, name, provider)',store)
        accept=store.split('function acceptPackageConfirmation()',1)[1].split('function toggleQuick',1)[0]
        self.assertIn('packageOperationConfirmed(action, name, provider)',accept)
        self.assertNotIn('requestPackageAuthorization(action, name, provider);\n    }',accept)

    def test_fullscreen_overlay_is_non_privileged(self):
        qml=(ROOT/'modules/main/PackageAuthorizationOverlay.qml').read_text()
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay',qml)
        self.assertIn('Store.approvePackageAuthorization()',qml)
        self.assertIn('Store.cancelPackageAuthorization()',qml)
        self.assertIn('HyprlandFocusGrab',qml)
        self.assertIn('Fingerprint',qml)
        self.assertIn('Password',qml)
        self.assertIn('Open system authentication',qml)
        for prohibited in ['passwordInput', 'TextInput {', 'PamContext', 'PolkitAgent {', 'sudo -S','echo $PASSWORD']:
            self.assertNotIn(prohibited,qml)
        self.assertNotIn('PackageAuthorizationOverlay {}',(ROOT/'shell.qml').read_text())

    def test_focus_released_before_polkit_process(self):
        page=(ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        self.assertIn('onPackageOperationConfirmed(action, packageName, provider)',page)
        self.assertIn('authorizedLaunchDelay.restart();',page)
        self.assertIn('interval: 320',page)
        self.assertIn('packageLauncher.exec(cmd)',page)
        self.assertIn('authorizedCommand.slice()',page)
        self.assertIn('!authorizedLaunchDelay.running',page)

    def test_native_fingerprint_authorization_remains_pam_owned(self):
        backend=SCRIPT.read_text()
        self.assertIn('fingerprint_configured=',backend)
        self.assertIn('pkexec',backend)
        self.assertNotIn('sudo -S',backend)
        self.assertIn('Graphical Polkit',backend)
        self.assertFalse((ROOT/'modules/main/PackageAuthorizationOverlay.qml').is_symlink())

if __name__=='__main__': unittest.main()
