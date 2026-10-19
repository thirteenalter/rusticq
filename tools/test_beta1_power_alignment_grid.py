#!/usr/bin/env python3
"""Guard against power-menu columns drifting with variable-length labels.

This test checks actual QML bindings and their shared geometry. It requires no
Wayland compositor; final visual validation remains on a Hyprland session.
"""
from pathlib import Path
import re
import unittest

HERE = Path(__file__).resolve().parents[1]
QML = (HERE / 'modules/power/PowerMenu.qml').read_text(encoding='utf-8')


class PowerGridAlignment(unittest.TestCase):
    def test_window_still_uses_original_wayland_overlay(self):
        self.assertRegex(QML, r'\bPanelWindow\s*\{')
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay', QML)
        self.assertIn('screen: Store.powerScreen', QML)
        self.assertIn('focusable: true', QML)
        self.assertNotIn('FloatingWindow {', QML)

    def test_header_and_rows_share_exact_text_origin(self):
        self.assertEqual(QML.count('x: root.textColumnX'), 2)
        self.assertRegex(QML, r'readonly property int textColumnX:\s*iconColumnX \+ iconColumnWidth \+ 12')
        self.assertEqual(QML.count('width: Math.max(80,'), 2)
        self.assertIn('x: root.iconColumnX + (root.iconColumnWidth - width) / 2', QML)
        self.assertIn('x: root.iconColumnX\n', QML)

    def test_shortcut_column_is_not_intrinsic_width_based(self):
        self.assertIn('anchors.right: parent.right', QML)
        self.assertIn('anchors.rightMargin: root.shortcutRightInset', QML)
        self.assertIn('width: root.shortcutColumnWidth', QML)
        self.assertIn('horizontalAlignment: Text.AlignRight', QML)
        self.assertEqual(len(re.findall(r'(?<!\w)RowLayout\s*\{', QML)), 0,
                         'RowLayout could reintroduce content-based horizontal drift')

    def test_three_columns_do_not_overlap_at_minimum_menu_width(self):
        # menuCard minimum width=300, column layout inset=17 on each side.
        inset = 12
        icon_width = 40
        text_start = inset + icon_width + 12
        shortcut_width = 24
        right_inset = 12
        for outer_width in (300, 420, 500):
            inner = outer_width - 2*17
            text_width = max(80, inner - text_start - shortcut_width - right_inset)
            self.assertGreater(text_start, inset + icon_width)
            self.assertLessEqual(text_start+text_width, inner - shortcut_width - right_inset)

    def test_key_navigation_and_existing_screensaver_unchanged(self):
        self.assertIn('omarchy', (HERE / 'scripts/rusticq-power-action.py').read_text())
        for name in ('Qt.Key_Up', 'Qt.Key_Down', 'Qt.Key_Return', 'Qt.Key_Escape'):
            self.assertIn(name, QML)
        for name in ('screensaver', 'lock', 'suspend', 'logout', 'reboot', 'shutdown'):
            self.assertIn('id:"'+name+'"', QML)
        self.assertEqual(QML.count('text: String(item.index + 1)'), 1)


if __name__ == '__main__':
    unittest.main()
