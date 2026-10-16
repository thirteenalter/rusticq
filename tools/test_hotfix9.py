#!/usr/bin/env python3
"""Source-level regression tests; does not substitute running a Linux shell."""
from pathlib import Path
import re
import unittest
R=Path(__file__).resolve().parents[1]
get=lambda rel:(R/rel).read_text()
class Hotfix9(unittest.TestCase):
    def test_aether_source_persistence(self):
        s=get('config/SettingsStore.qml')
        self.assertIn('property string colorSource: "gruvbox"',s)
        self.assertIn('data.colorSource',s)
        self.assertIn('colorSource: colorSource',s)
    def test_watched_palette_and_fallback(self):
        s=get('config/Theme.qml')
        for word in ['aether/theme/colors.toml','watchChanges: true','onFileChanged: aetherFile.reload()',
                     'onLoaded: root.parseAether(aetherFile.text())','SettingsStore.colorSource === "aether"',
                     'useAether ? aetherPalette.background : "#282828"', 'useAether ? aetherPalette.foreground : "#ebdbb2"']:
            self.assertIn(word,s)
        self.assertNotIn('eval(',s)
    def test_mini_controls_are_shared(self):
        source=get('modules/main/IndicatorPopup.qml')
        for word in ['PopupWindow {','anchor.window: hostWindow','grabFocus: true','BarWifi { standalone: true }',
                     'BarBluetooth { standalone: true }','BarBattery { standalone: true }','MiniAudio {}']:
            self.assertIn(word,source)
        icons=get('components/Indicators.qml')
        for kind in ['wifi','bluetooth','battery','audio']:
            self.assertIn('"'+kind+'"',icons)
            self.assertIn('onActivated:',icons)
        self.assertIn('onIconClicked:',get('modules/main/Bar.qml'))
    def test_weekday_dates_all_modes(self):
        self.assertIn('"ddd, dd MMM" : "dddd, dd MMM"',get('components/Clock.qml'))
        self.assertIn('showDate: SettingsStore.showDate',get('modules/main/Bar.qml'))
    def test_settings_source_selector(self):
        s=get('modules/settings/SettingsWindow.qml')
        self.assertIn('Follow Aether',s)
        self.assertIn('Independent Gruvbox',s)
        self.assertIn('Theme.aetherAvailable',s)
    def test_no_credentials(self):
        s=get('user-settings.json')
        self.assertNotRegex(s,r'(?i)api[_-]?key|secret[_-]?token')
if __name__ == '__main__':unittest.main()
