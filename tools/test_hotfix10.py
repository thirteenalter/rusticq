#!/usr/bin/env python3
"""Hotfix 10 source/asset regression tests (not a real Wayland runtime test)."""
from pathlib import Path
import re
import unittest
try:
    from fontTools.ttLib import TTFont
except ImportError:
    TTFont = None

ROOT = Path(__file__).resolve().parents[1]
class IndicatorPopupFix(unittest.TestCase):
    def read(self, path):
        return (ROOT/path).read_text(encoding='utf-8')

    def test_window_coordinate_mapping_is_valid_for_qswindow(self):
        bar = self.read('modules/main/Bar.qml')
        self.assertIn('barWindow.mapFromItem(indicators, localX, 0)', bar)
        self.assertNotIn('indicators.mapToItem(barWindow', bar)
        self.assertIn('barWindow.openMini(kind, pos.x)', bar)
        self.assertLess(bar.index('miniAnchorX = xPosition'),bar.index('miniKind = kind;'))

    def test_all_indicator_buttons_emit_actual_click(self):
        widget=self.read('components/Indicators.qml')
        for kind, name in [('wifi', 'wifiIndicator'), ('bluetooth', 'btIndicator'),
                           ('battery', 'batteryIndicator'), ('audio', 'audioIndicator')]:
            self.assertIn(f'root.notify("{kind}", {name})', widget)
        for name in ['Wifi','Bluetooth','Battery','Audio']:
            source=self.read(f'components/{name}.qml')
            self.assertIn('signal activated()', source)
            self.assertIn('onClicked: root.activated()', source)

    def test_popup_window_sizes_not_deprecated(self):
        p=self.read('modules/main/IndicatorPopup.qml')
        self.assertIn('implicitWidth: kind === "menu" ? 294 : 368', p)
        self.assertIn('implicitHeight: kind === "wifi"', p)
        self.assertNotRegex(p, r'(?m)^\s*(width|height):\s*')
        for key in ['anchor.window: hostWindow','anchor.rect.x:', 'anchor.rect.y:',
                    'grabFocus: true', 'onKindChanged: visible = kind !== ""',
                    'onVisibleChanged: if (!visible && kind !== "") dismissed()']:
            self.assertIn(key, p)
        for name in ['BarWifi','BarBluetooth','BarBattery','MiniAudio']:
            self.assertIn(name+' {',p)

    def test_battery_icons_exist_in_bundled_google_font(self):
        if TTFont is None:
            self.skipTest('Optional glyph verification requires python-fonttools')
        battery=self.read('services/BatteryService.qml')
        f=TTFont(str(ROOT/'assets/google.ttf'))
        cmap=f.getBestCmap()
        expected={
            0xf302:'battery_android_question', 0xf304:'battery_android_full',
            0xf305:'battery_android_bolt', 0xf307:'battery_android_6',
            0xf308:'battery_android_5', 0xf309:'battery_android_4',
            0xf30a:'battery_android_3', 0xf30b:'battery_android_2',
            0xf30c:'battery_android_1', 0xf30d:'battery_android_0'
        }
        for cp, glyph in expected.items():
            with self.subTest(icon=glyph):
                self.assertEqual(cmap.get(cp), glyph)
                self.assertIn(r'\u%04x'%cp,battery)
        for source in ['components/Battery.qml','modules/bar/BarBattery.qml']:
            self.assertIn('BatteryService.icon', self.read(source))

    def test_sidebar_and_appearance_preserved(self):
        self.assertIn('aether/theme/colors.toml',self.read('config/Theme.qml'))
        self.assertIn('colorSource',self.read('config/SettingsStore.qml'))
        bar=self.read('modules/main/Bar.qml')
        self.assertIn('Store.toggleQuick(barWindow.screen)',bar)
        self.assertIn('Store.toggleAi(barWindow.screen)',bar)

if __name__=='__main__':
    unittest.main()
