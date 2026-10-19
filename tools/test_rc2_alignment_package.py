#!/usr/bin/env python3
"""Offline regression checks for the RC2 alignment / package patch."""
from pathlib import Path
import importlib.util
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class TestPatch(unittest.TestCase):
    def test_alignment(self):
        store = (ROOT / 'config/SettingsStore.qml').read_text()
        editor = (ROOT / 'modules/settings/pages/BarAlignmentEditor.qml').read_text()
        zone = (ROOT / 'components/BarZone.qml').read_text()
        bar = (ROOT / 'modules/main/Bar.qml').read_text()
        vertical = (ROOT / 'modules/main/VerticalBarContent.qml').read_text()
        for key in ['arch','launcher','menu','workspaces','weather','time','date','bluetooth','wifi','battery','audio','task','quickModes','quickControl','mic','down','up']:
            self.assertIn('"' + key + '"', store)
            self.assertIn('key:"' + key + '"', editor)
        for zone_key in ['left','center','right']:
            self.assertIn('zone: "' + zone_key + '"', bar)
            self.assertIn('zone: "' + zone_key + '"', vertical)
        self.assertIn('SettingsStore.placementFor(k) === zone', zone)
        self.assertIn('barIconPlacements: barIconPlacements', store)
        self.assertIn('resetIconPlacements()', store)

    def test_icons(self):
        from fontTools.ttLib import TTFont
        font = TTFont(ROOT/'assets/google.ttf')
        cmap = font.getBestCmap()
        for code in [0xe322,0xf500,0xf371,0xe04f,0xe04d,0xe04e,0xe050]:
            self.assertIn(code, cmap)
        self.assertIn('"\\uf371"', (ROOT/'components/Arch.qml').read_text())
        self.assertIn('"\\ue322"', (ROOT/'components/BarZone.qml').read_text())

    def test_packages_are_never_automatic(self):
        source = (ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        self.assertIn('confirmationText !== pendingPackage', source)
        self.assertIn('root.pendingAction === "remove"', source)
        self.assertIn('onClicked: root.confirmPackage()', source)
        self.assertIn('onClicked: root.requestOperation("remove"', source)
        self.assertNotIn('onCompleted: confirmPackage()', source)

    def test_helper_guards_and_commands(self):
        spec = importlib.util.spec_from_file_location('pkg', ROOT/'scripts/rustiq-package-manager.py')
        pkg = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(pkg)
        for bad in [';rm -rf /', '--needed', 'test name', '../../x', '']:
            with self.assertRaises(ValueError):
                pkg.validate_package(bad)
        self.assertEqual(pkg.make_commands('remove','foo'), [['sudo','pacman','-R','--','foo']])
        self.assertEqual(pkg.make_commands('install','foo',omarchy=True), [['omarchy','update'],['sudo','pacman','-S','--','foo']])
        self.assertEqual(pkg.make_commands('install','foo',omarchy=False), [['sudo','pacman','-Syu','--','foo']])
        with self.assertRaises(ValueError):
            pkg.resolve_desktop('../evil.desktop')
        with self.assertRaises(ValueError):
            pkg.make_commands('remove','evil;true')


if __name__ == '__main__':
    unittest.main(verbosity=2)
