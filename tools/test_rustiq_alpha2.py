#!/usr/bin/env python3
"""RusticQ alpha-2 structural regression tests. Requires runtime to validate geometry."""
import unittest
from pathlib import Path
try:
    from fontTools.ttLib import TTFont
except ImportError:
    TTFont=None
ROOT=Path(__file__).resolve().parents[1]
read=lambda name:(ROOT/name).read_text(encoding='utf-8')

class Alpha2MiniWidgetTests(unittest.TestCase):
    def test_standalone_content_always_open_without_chevron(self):
        popup=read('modules/main/IndicatorPopup.qml')
        for name in ('Wifi','Bluetooth','Battery'):
            self.assertIn(f'Bar{name} {{ standalone: true }}',popup)
            src=read(f'modules/bar/Bar{name}.qml')
            self.assertIn('property bool standalone: false',src)
            self.assertIn('readonly property bool contentOpen: standalone || expanded',src)
            self.assertIn('collapsible: !',src)
            self.assertIn('onToggleRequested: if (!',src)
            self.assertIn('visible: ',src)
            self.assertIn('contentOpen',src)
        self.assertIn('anchors.fill: parent',popup)
        self.assertIn('anchors.margins: 8',popup)

    def test_full_quick_control_still_has_collapse_state(self):
        parent=read('modules/bar/BarMain.qml')
        self.assertIn('BarWifi {',parent)
        self.assertIn('BarBluetooth {',parent)
        self.assertIn('BarBattery {',parent)
        header=read('components/SectionHeader.qml')
        self.assertIn('property bool collapsible: true',header)
        self.assertIn('visible: root.collapsible',header)
        self.assertIn('enabled: root.collapsible',header)
        self.assertIn('onClicked: root.toggleRequested()',header)

    def test_quick_control_symbol_is_in_bundled_google_font(self):
        for file in ['modules/main/Bar.qml','modules/bar/BarHeader.qml','components/PowerButton.qml']:
            self.assertIn(r'\ue69b',read(file),file)
        self.assertNotIn(r'\ue69b',read('components/Arch.qml')) # AI still distinct
        if TTFont is None:
            self.skipTest('fonttools unavailable for actual font inspection')
        cmap=TTFont(ROOT/'assets/google.ttf').getBestCmap()
        self.assertEqual(cmap.get(0xe69b),'stat_minus_1')

if __name__=='__main__': unittest.main()
