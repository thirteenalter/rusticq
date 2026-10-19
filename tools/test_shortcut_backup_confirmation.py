#!/usr/bin/env python3
"""Contract tests for visible backup confirmation and independently usable Verify."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class BackupConfirmation(unittest.TestCase):
    def test_confirmation_is_a_real_settings_workspace_window(self):
        shell = (ROOT/'shell.qml').read_text()
        store = (ROOT/'config/Store.qml').read_text()
        dialog = (ROOT/'modules/main/ShortcutBackupConfirmationWindow.qml').read_text()
        helper = (ROOT/'scripts/rustiq-shortcut-confirmation-float.py').read_text()
        self.assertIn('active: Store.shortcutConfirmVisible', shell)
        self.assertIn('ShortcutBackupConfirmationWindow {}', shell)
        self.assertIn('signal shortcutBackupApproved()', store)
        self.assertIn('shortcutConfirmScreen = settingsScreen', store)
        self.assertIn('FloatingWindow {', dialog)
        self.assertIn('Back up & continue', dialog)
        self.assertIn('acceptedRecovery', dialog)
        self.assertIn('Store.approveShortcutConfirmation()', dialog)
        self.assertIn('RusticQ · Shortcut Backup Confirmation', helper)
        self.assertIn('SETTINGS_TITLE', helper)
        self.assertIn('target_ws', helper)

    def test_verify_always_enabled_and_snapshot_intent_captured(self):
        page = (ROOT/'modules/settings/pages/SettingsShortcutsPage.qml').read_text()
        script = (ROOT/'scripts/rustiq-desktop-integration.py').read_text()
        self.assertIn('onClicked: root.change("verify-shortcut-backups")', page)
        self.assertNotIn('!root.busy && root.shortcutArchives.count > 0', page)
        self.assertIn('Create backup now', page)
        self.assertIn('Store.requestShortcutConfirmation', page)
        self.assertIn('const frozen = buildCommand(verb, selectedAction)', page)
        self.assertIn('onShortcutBackupApproved', page)
        self.assertIn("'create-shortcut-backup': create_shortcut_backup_now", script)
        self.assertIn('verify_shortcut_archive(target)', script)
        self.assertNotIn("backup_omarchy()" + "\n" + "            verify_omarchy_backup", script)

if __name__ == '__main__':
    unittest.main()
