#!/usr/bin/env python3
"""Static design contract: the native lock shares RusticQ styling; no auth changes."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SURFACE = ROOT / 'modules/lock/RusticQLockSurface.qml'
APPEARANCE = ROOT / 'modules/settings/pages/SettingsAppearancePage.qml'
MINILAUNCHER = ROOT / 'modules/main/MiniLauncher.qml'
POWER = ROOT / 'modules/power/PowerMenu.qml'
CONTROLLER = ROOT / 'lockscreen.qml'

class NativeVisualContract(unittest.TestCase):
    def test_same_card_tokens_as_launcher(self):
        surface = SURFACE.read_text()
        launcher = MINILAUNCHER.read_text()
        power = POWER.read_text()
        for token in ('radius: Theme.sectionRadius', 'border.color: Theme.borderaccent',
                      'border.width: 1', 'color: Theme.background'):
            self.assertIn(token, surface)
            self.assertIn(token, launcher)
            self.assertIn(token, power)
        for token in ('Theme.accent', 'Theme.foreground', 'Theme.muted',
                      'Theme.surface', 'Theme.rowRadius', 'Fonts.poppinsSB.name',
                      'Fonts.poppins.name', 'Fonts.scale('):
            self.assertIn(token, surface)
        self.assertNotIn('readonly property color accent:', surface)
        self.assertNotIn('"#e51c2324"', surface)

    def test_preview_matches_surface_and_is_not_a_login_form(self):
        preview = APPEARANCE.read_text().split('id: nativeLockPreview', 1)[1]
        self.assertIn('Theme.sectionRadius', preview)
        self.assertIn('Theme.borderaccent', preview)
        self.assertIn('SettingsStore.lockscreenBackground', preview)
        self.assertIn('Welcome back', preview)
        self.assertIn('Wayland session lock', preview)
        self.assertIn('Unlock session', preview)
        self.assertNotIn('TextInput {', preview)
        self.assertNotIn('PamContext {', preview)

    def test_auth_is_only_in_dedicated_controller(self):
        surface = SURFACE.read_text()
        controller = CONTROLLER.read_text()
        self.assertIn('WlSessionLockSurface {', surface)
        self.assertIn('TextInput.Password', surface)
        self.assertIn('clear(); // Wipe', surface)
        self.assertIn('surface.controller.submit(response);', surface)
        self.assertNotIn('sessionLock.locked = false', surface)
        self.assertNotIn('PamContext {', surface)
        self.assertEqual(controller.count('sessionLock.locked = false;'), 1)
        self.assertIn('if (result === PamResult.Success && sessionLock.secure)', controller)

if __name__ == '__main__':
    unittest.main()
