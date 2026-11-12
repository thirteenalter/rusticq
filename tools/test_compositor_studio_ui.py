#!/usr/bin/env python3
"""GUI integration checks separate from backend rollback/syntax tests."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class UiContract(unittest.TestCase):
    def test_settings_has_navigation_and_correct_loader(self):
        source=(ROOT/'modules/settings/SettingsWindow.qml').read_text()
        self.assertIn('{key:"compositor", label:"Compositor"',source)
        self.assertIn('Store.settingsTab === "compositor" ? compositorPage',source)
        self.assertIn('Component { id: compositorPage; SettingsCompositorPage {} }',source)
    def test_preview_and_apply_require_token(self):
        page=(ROOT/'modules/settings/pages/SettingsCompositorPage.qml').read_text()
        self.assertIn('root.token.length > 0 && !actionProc.running',page)
        self.assertIn('function changed() { token = ""',page)
        self.assertIn('frozenValues = values()',page)
    def test_niri_readonly_ui(self):
        page=(ROOT/'modules/settings/pages/SettingsCompositorPage.qml').read_text()
        self.assertIn('enabled: tile.enabledHere',page)
        self.assertIn('Read-only on this backend',page)
    def test_no_duplicate_keybinding_editor(self):
        page=(ROOT/'modules/settings/pages/SettingsCompositorPage.qml').read_text()
        self.assertIn('Settings → Shortcuts',page)
        self.assertNotIn('hl.bind(',page)
    def test_rollback_exposed(self):
        page=(ROOT/'modules/settings/pages/SettingsCompositorPage.qml').read_text()
        self.assertIn('root.doRollback()',page)
        self.assertIn('Backup history & rollback',page)
if __name__=='__main__': unittest.main(verbosity=2)
