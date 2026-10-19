#!/usr/bin/env python3
"""Offline regressions for parsing real pacman, yay, Flatpak CLI output.

Never calls a real package manager or executes installation/removal.
"""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('packagehotfix', ROOT / 'scripts/rustiq-package-manager.py')
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)

PACMAN = '''extra/firefox 141.0-1 [installed]
    Fast and secure web browser
extra/foot 1.23.2-1
    Wayland terminal emulator
'''
YAY = '''\x1b[1;35maur/ventoy-bin\x1b[0m 1.1.10-1 (+37 0.34) [installed: 1.1.09-1]
    A new bootable USB solution
extra/ventoy 1.0.0-1
    Source packages that must be filtered out for AUR
\x1b[32maur/ventoy-git\x1b[0m 1.0.3-1 (+1 0.01)
    Latest Ventoy version
'''
FLATPAK = '''Application ID\tName\tDescription\tVersion\tRemotes
org.gimp.GIMP\tGNU Image Manipulation Program\tCreate and edit images\t3.0.0\tflathub
org.mozilla.firefox\tFirefox\tFirefox Browser\t140.0\tflathub
'''

class ProviderTests(unittest.TestCase):
    def test_pacman_two_line_format(self):
        got = manager.parse_repo_results(PACMAN, 'pacman')
        self.assertEqual(len(got), 2)
        self.assertEqual(got[0]['name'], 'firefox')
        self.assertTrue(got[0]['installed'])
        self.assertEqual(got[1]['description'], 'Wayland terminal emulator')

    def test_yay_ansi_and_installed_version_not_lost(self):
        got = manager.parse_repo_results(YAY, 'yay')
        self.assertEqual([i['name'] for i in got], ['ventoy-bin', 'ventoy-git'])
        self.assertTrue(got[0]['installed'])
        self.assertEqual(got[0]['description'], 'A new bootable USB solution')

    def test_flatpak_header_and_complete_app_ids(self):
        got = manager.parse_flatpak_results(FLATPAK)
        self.assertEqual(len(got), 2)
        self.assertEqual(got[0]['name'], 'org.gimp.GIMP')
        self.assertEqual(got[0]['remote'], 'flathub')

    def test_flatpak_ascii_aligned_format(self):
        got = manager.parse_flatpak_results('org.gimp.GIMP  GIMP editor  Free Image Editor  3.0  flathub\n')
        self.assertEqual(got[0]['name'], 'org.gimp.GIMP')

    def test_search_yay_uses_cli_search_and_filters_repo(self):
        with patch.object(manager.shutil, 'which', return_value='/usr/bin/yay'), \
             patch.object(manager, 'cmd_output', return_value=subprocess.CompletedProcess([],0,YAY,'')) as called:
            got = manager.search_yay('ventoy-bin')
        self.assertEqual(got[0]['name'], 'ventoy-bin')
        self.assertEqual(called.call_args.args[0], ['yay','-Ss','ventoy-bin'])

    def test_flatpak_installed_lookup_timeout_keeps_search_results(self):
        def fake(command, timeout=20):
            if command[1] == 'search':
                return subprocess.CompletedProcess(command, 0, FLATPAK, '')
            raise subprocess.TimeoutExpired(command, timeout)
        with patch.object(manager.shutil, 'which', return_value='/usr/bin/flatpak'), \
             patch.object(manager, 'cmd_output', side_effect=fake) as caller:
            found = manager.search_flatpak('gimp')
        self.assertEqual(found[0]['name'], 'org.gimp.GIMP')
        self.assertIn('application:full', caller.call_args_list[0].args[0][2])

    def test_search_source_echoes_query_for_stale_results_guard(self):
        with patch.object(manager.shutil, 'which', return_value='/usr/bin/pacman'), \
             patch.object(manager, 'search_pacman', return_value=manager.parse_repo_results(PACMAN, 'pacman')):
            response = manager.search_source('pacman','firefox')
        self.assertEqual(response['query'],'firefox')
        self.assertEqual(response['results'][0]['name'],'firefox')

    def test_search_provider_error_instead_of_never_ending_loading(self):
        with patch.object(manager.shutil, 'which', return_value='/usr/bin/flatpak'), \
             patch.object(manager, 'search_flatpak', side_effect=subprocess.TimeoutExpired(['flatpak'], 14)):
            result = manager.search_source('flatpak','gimp')
        self.assertTrue(result['ok'])
        self.assertTrue(result['errors'])
        self.assertEqual(result['results'], [])

    def test_qml_has_provider_state_and_out_of_order_guard(self):
        s=(ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        self.assertIn('payload.query !== searchedQuery',s)
        self.assertIn('providerExited',s)
        self.assertIn('catalogSearchPacman',s)
        self.assertIn('catalogSearchYay',s)
        self.assertIn('catalogSearchFlatpak',s)

    def test_power_is_previous_fullscreen_layer(self):
        s=(ROOT/'modules/power/PowerMenu.qml').read_text()
        self.assertIn('PanelWindow {',s)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay',s)
        self.assertNotIn('FloatingWindow {',s)
        self.assertIn('screen: Store.powerScreen',s)

if __name__ == '__main__':
    unittest.main()
