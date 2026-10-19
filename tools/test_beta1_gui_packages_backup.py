#!/usr/bin/env python3
"""Offline transaction and full-Omarchy-backup regression suite. No sudo/pacman."""
from pathlib import Path
import importlib.util
import json
import os
import tempfile
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

PKG = load('scripts/rustiq-package-manager.py', 'rusticq_pkg_test')
DEPS = load('scripts/rusticq-dependencies.py', 'rusticq_deps_test')
INTEGRATION = load('scripts/rustiq-desktop-integration.py', 'rusticq_integration_test')


class GuiPackagesTest(unittest.TestCase):
    def test_unknown_package_and_action_fail_closed(self):
        for package in ('foo; sh', '../../bin', 'foo\nbar', ''):
            with self.assertRaises(ValueError):
                PKG.validate_package(package)
        with self.assertRaises(ValueError):
            PKG.validate_request('force-remove', 'pacman')
        with patch.object(PKG.shutil, 'which', return_value='/usr/bin/pacman'):
            with self.assertRaisesRegex(RuntimeError, 'protected'):
                PKG.validate_request('remove', 'hyprland')

    def test_gui_pkexec_direct_never_user_owned_root_python(self):
        with patch.object(PKG, 'validate_request', return_value='firefox'), \
             patch.object(PKG.Path, 'is_file', return_value=True), \
             patch.object(PKG.shutil, 'which', return_value=None), \
             patch.object(PKG, 'run', return_value=subprocess.CompletedProcess([], 0, 'firefox\n', '')) as verify, \
             patch.object(PKG.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, '', '')) as execute:
            response = PKG.graphical_transaction('install', 'firefox')
        command = execute.call_args.args[0]
        self.assertTrue(response['ok'])
        self.assertEqual(command[:3], ['/usr/bin/pkexec', '--disable-internal-agent', '/usr/bin/pacman'])
        self.assertIn('--noconfirm', command)
        self.assertEqual(command[-2:], ['--', 'firefox'])
        self.assertNotIn('python3', command)
        self.assertNotIn('sudo', command)
        verify.assert_called_once()

    def test_removal_no_force_and_reports_failure(self):
        with patch.object(PKG, 'validate_request', return_value='firefox'), \
             patch.object(PKG.Path, 'is_file', return_value=True), \
             patch.object(PKG.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'cancelled')) as execute:
            response = PKG.graphical_transaction('remove', 'firefox')
        command = execute.call_args.args[0]
        self.assertFalse(response['ok'])
        self.assertEqual(command[3:5], ['-R', '--noconfirm'])
        self.assertNotIn('-Rdd', command)
        self.assertIn('cancelled', response['message'])

    def test_dependency_allowlist_and_core_safety(self):
        with self.assertRaises(ValueError):
            DEPS.gui_manage('not-an-id', 'install', 'INSTALL not-an-id')
        with self.assertRaises(ValueError):
            DEPS.gui_manage('network', 'remove', 'INSTALL network')
        with self.assertRaises(ValueError):
            DEPS.gui_manage('python', 'remove', 'REMOVE python')
        with self.assertRaises(ValueError):
            DEPS.gui_manage('network', 'purge', 'PURGE network')

    def test_gui_only_main_entrypoint(self):
        with self.assertRaisesRegex(ValueError, 'retired'):
            PKG.main(['launch', 'install', 'firefox'])
        info = (ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        integration = (ROOT/'modules/settings/pages/SettingsIntegrationPage.qml').read_text()
        self.assertIn('"gui", pendingProvider, pendingAction, pendingPackage', info)
        self.assertIn('"--operation", selectedDependencyAction', integration)
        self.assertIn('selectedDependencyAction.toUpperCase()', integration)
        dialog = (ROOT/'modules/main/PackageConfirmationWindow.qml').read_text()
        self.assertIn('graphical Polkit', dialog)
        self.assertNotIn('terminal still asks', dialog)


class OmarchySnapshotTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        config = root/'config'
        state = root/'state'/'rusticq'/'integration'
        installed = root/'share'/'rusticq'/'shell'
        source = root/'project'
        source.mkdir()
        (source/'shell.qml').write_text('// test shell\n')
        omarchy = root/'omarchy'/'default'/'hypr'
        omarchy.mkdir(parents=True)
        (omarchy/'autostart.lua').write_text('hl.exec_cmd("omarchy-launch-shell")\n')
        (omarchy/'monitors.lua').write_text('-- default monitor\n')
        (config/'hypr').mkdir(parents=True)
        (config/'hypr'/'hyprland.lua').write_text('require("default.hypr.omarchy")\n')
        (config/'hypr'/'bindings.lua').write_text('-- original keybinds\n')
        (config/'hypr'/'monitors.lua').write_text('-- customized monitor\n')
        (config/'omarchy').mkdir()
        (config/'omarchy'/'shell.json').write_text('{"enabled":true}\n')
        (config/'quickshell').mkdir()
        (config/'quickshell'/'user-settings.json').write_text('{"theme":"private"}')
        (config/'hypr'/'my-link').symlink_to('monitors.lua')
        mapping = dict(ROOT=source, CONFIG=config, STATE=state, DATA=installed,
                       HYPR=config/'hypr', MAIN=config/'hypr'/'hyprland.lua',
                       BINDINGS=config/'hypr'/'bindings.lua', DEFAULT_AUTOSTART=omarchy/'autostart.lua',
                       META=state/'manifest.json', SHORTCUTS=state/'shortcuts.json',
                       SHORTCUT_BACKUPS=state/'shortcut-line-backups.json', REMAPS=state/'remaps.json',
                       OMARCHY_BACKUP_META=state/'backup'/'omarchy-snapshot.json',
                       SHIM=state/'autostart.lua', STARTER=state/'start-rusticq.sh',
                       TREE_ROOT=state/'backup'/'user-config-preinstall',
                       TREE_META=state/'backup'/'user-config-index.json')
        shared = patch.multiple(INTEGRATION, **mapping)
        shared.start()
        self.addCleanup(shared.stop)
        env = patch.dict(os.environ, {'OMARCHY_PATH': str(root/'omarchy'),
                                      'HYPRLAND_INSTANCE_SIGNATURE': ''})
        env.start()
        self.addCleanup(env.stop)
        self.config = config
        self.omarchy = omarchy

    def test_snapshot_all_trees_and_symlink_integrity(self):
        result = INTEGRATION.backup_omarchy()
        self.assertTrue(result['ok'])
        verify = INTEGRATION.verify_omarchy_backup()
        self.assertTrue(verify['full'])
        self.assertGreaterEqual(verify['user_files'], 5)
        self.assertTrue((INTEGRATION.TREE_ROOT/'hypr'/'my-link').is_symlink())
        self.assertEqual((INTEGRATION.TREE_ROOT/'hypr'/'monitors.lua').read_text(), '-- customized monitor\n')
        self.assertEqual((INTEGRATION.TREE_ROOT/'quickshell'/'user-settings.json').stat().st_mode & 0o777, 0o600)
        again = INTEGRATION.backup_omarchy()
        self.assertFalse(again['created'])
        self.assertEqual(INTEGRATION.backup_health()['user_files'], verify['user_files'])

    def test_checksum_corruption_blocks_activation(self):
        INTEGRATION.backup_omarchy()
        (INTEGRATION.TREE_ROOT/'hypr'/'monitors.lua').write_text('-- changed snapshot')
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            INTEGRATION.enable_permanent('ENABLE RUSTICQ')
        self.assertFalse(INTEGRATION.META.exists())
        self.assertFalse(INTEGRATION.DATA.exists())

    def test_activation_and_revert_preserve_other_user_files(self):
        result = INTEGRATION.enable_permanent('ENABLE RUSTICQ')
        self.assertTrue(result['ok'])
        self.assertTrue(INTEGRATION.META.exists())
        self.assertIn(INTEGRATION.START, INTEGRATION.MAIN.read_text())
        (self.config/'hypr'/'monitors.lua').write_text('-- edited while rusticq active\n')
        revert = INTEGRATION.revert_permanent('RESTORE OMARCHY')
        self.assertTrue(revert['ok'])
        self.assertEqual(INTEGRATION.MAIN.read_text(), 'require("default.hypr.omarchy")\n')
        self.assertEqual((self.config/'hypr'/'monitors.lua').read_text(), '-- edited while rusticq active\n')
        self.assertTrue(list((INTEGRATION.STATE/'revert-history').glob('pre-revert-*')))
        self.assertTrue(INTEGRATION.TREE_META.is_file())
        self.assertEqual((self.omarchy/'autostart.lua').read_text(), 'hl.exec_cmd("omarchy-launch-shell")\n')


if __name__ == '__main__':
    unittest.main()
