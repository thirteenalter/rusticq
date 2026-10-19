#!/usr/bin/env python3
"""Contract checks for the user-visible Settings updater controls."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

class IntegrationUI(unittest.TestCase):
    def test_shell_update_controls_are_wired(self):
        page=(ROOT/'modules/settings/pages/SettingsIntegrationPage.qml').read_text()
        script=(ROOT/'scripts/rusticq-shell-updates.py').read_text()
        for part in ('Shell Updates', 'Reapply Local', 'Check GitHub', 'Update Shell (GitHub)',
                     'Rollback Shell', 'shellUpdateApply()', 'shellUpdateRefresh()', 'shellUpdateCheck()',
                     'REAPPLY LOCAL', 'UPDATE SHELL', 'ROLLBACK SHELL', 'shellUpdatePoll'):
            self.assertIn(part, page,part)
        for command in ('check', 'status', 'reapply-local', 'update-shell', 'rollback'):
            self.assertIn("'"+command+"'",script)
        self.assertIn('shellUpdateStatusProc',page)
        self.assertIn('root.shellUpdateConfirm === updateConfirmColumn.phrase',page)
        self.assertIn('if (!root.shellUpdateCheckedOnce',page)
        self.assertIn('property string shellUpdateTarget: "dev"',page)
        self.assertIn('shellUpdateTargetBackups',page)
        self.assertIn('shellUpdateTargetReady',page)
        self.assertIn('Qt.callLater(root.refreshIntegrationProgress)',page)
        self.assertIn('scripts/rusticq-shell-updates.py',page)

if __name__ == '__main__':unittest.main()
