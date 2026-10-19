#!/usr/bin/env python3
"""Offline GUI search-provider and power-menu safety tests. No package installs."""
import importlib.util
import json
import subprocess
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

def load(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

PKG = load('scripts/rustiq-package-manager.py', 'pkg_sources')
PWR = load('scripts/rusticq-power-action.py', 'power_action')

class SearchTests(unittest.TestCase):
    def test_repo_and_aur_parser(self):
        sample = ('extra/firefox 122.0-1 [installed]\n    Fast browser\naur/firefox-nightly 124.0\n    Test browser\n')
        out = PKG.parse_repo_results(sample, 'pacman')
        self.assertEqual([a['name'] for a in out], ['firefox','firefox-nightly'])
        self.assertEqual(out[0]['description'], 'Fast browser')
        self.assertTrue(out[0]['installed'])
        aur = PKG.parse_repo_results(sample, 'yay')
        self.assertEqual([a['name'] for a in aur], ['firefox-nightly'])

    def test_flatpak_parser(self):
        data='org.mozilla.firefox\tFirefox\tWeb browser\t129.0\tflathub\n'
        out = PKG.parse_flatpak_results(data)
        self.assertEqual(out[0]['name'], 'org.mozilla.firefox')
        self.assertEqual(out[0]['remote'], 'flathub')

    def test_all_sources_by_default(self):
        with patch.object(PKG.shutil, 'which', return_value='/bin/mock'), \
             patch.object(PKG, 'search_pacman', return_value=[{'source':'pacman'}]) as pacman, \
             patch.object(PKG, 'search_yay', return_value=[{'source':'yay'}]) as yay, \
             patch.object(PKG, 'search_flatpak', return_value=[{'source':'flatpak'}]) as flatpak:
            result = PKG.search_sources('firefox')
        self.assertEqual([i['source'] for i in result['results']], ['pacman','yay','flatpak'])
        self.assertTrue(all(result['available'].values()))
        pacman.assert_called_once()
        yay.assert_called_once()
        flatpak.assert_called_once()

    def test_no_search_command_injection(self):
        for query in ['x;rm -rf /', '$(touch /tmp/x)', 'x\nshutdown','a',' ' * 2]:
            with self.assertRaises(ValueError):
                PKG.search_sources(query)
        self.assertEqual(PKG.validate_source_package('flatpak','org.gnome.Calculator'), 'org.gnome.Calculator')
        with self.assertRaises(ValueError):
            PKG.validate_source_package('flatpak','--system')
        with self.assertRaises(ValueError):
            PKG.validate_source('http')

    def test_yay_invoked_as_user_and_uses_polkit(self):
        with patch.object(PKG.shutil, 'which', return_value='/bin/mock'), \
             patch.object(PKG.os, 'geteuid', return_value=1000), \
             patch.object(PKG, 'cmd_output') as execute:
            execute.side_effect = [
                subprocess.CompletedProcess([], 0, 'AUR package info', ''),
                subprocess.CompletedProcess([], 0, 'installed', ''),
                subprocess.CompletedProcess([], 0, 'my-aur-package', ''),
            ]
            result = PKG.source_transaction('yay','install','my-aur-package')
            self.assertTrue(result['ok'])
            args = execute.call_args_list[1].args[0]
            self.assertEqual(args[0], 'yay')
            self.assertIn('--sudo', args)
            self.assertIn('/usr/bin/pkexec', args)
            self.assertNotEqual(args[0], '/usr/bin/pkexec')

    def test_flatpak_uses_user_location(self):
        with patch.object(PKG.shutil, 'which', return_value='/bin/mock'), \
             patch.object(PKG, 'flatpak_location', return_value='--user'), \
             patch.object(PKG, 'flatpak_remotes', return_value={'flathub':'user'}), \
             patch.object(PKG, 'flatpak_installed', return_value={'org.gnome.Calculator':'user'}), \
             patch.object(PKG, 'cmd_output', return_value=subprocess.CompletedProcess([],0,'OK','')) as execute:
            result = PKG.source_transaction('flatpak','install','org.gnome.Calculator')
            self.assertTrue(result['ok'])
            cmd = execute.call_args_list[0].args[0]
            self.assertEqual(cmd[0:3], ['flatpak','install','--user'])

    def test_original_pacman_route_still_used(self):
        with patch.object(PKG, 'graphical_transaction', return_value={'ok': True}) as backend:
            self.assertTrue(PKG.source_transaction('pacman','install','firefox')['ok'])
            backend.assert_called_once_with('install','firefox')

    def test_gui_has_provider_labels_and_confirmation(self):
        settings = (ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        store = (ROOT/'config/Store.qml').read_text()
        confirm = (ROOT/'modules/main/PackageConfirmationWindow.qml').read_text()
        self.assertIn('Search apps · Pacman + Yay AUR + Flatpak', settings)
        self.assertIn('catalogDebounce', settings)
        self.assertIn('pendingProvider', settings)
        self.assertIn('confirmationProvider', store)
        self.assertIn('Store.confirmationProvider', confirm)
        self.assertIn('Review AUR PKGBUILD',confirm)

class PowerTests(unittest.TestCase):
    def test_power_actions_have_real_commands(self):
        with patch.object(PWR.shutil, 'which', return_value='/usr/bin/tool'):
            self.assertEqual(PWR.action_command('shutdown'), ['loginctl','poweroff'])
            self.assertEqual(PWR.action_command('reboot'), ['loginctl','reboot'])
            self.assertEqual(PWR.action_command('suspend'), ['loginctl','suspend'])
            self.assertEqual(PWR.action_command('logout'), ['hyprctl','dispatch','exit'])
            self.assertTrue(PWR.action_command('lock')[1].endswith('/scripts/rusticq-native-lock.py'))
        with self.assertRaises(ValueError):
            PWR.action_command('reboot; rm -rf /')

    def test_floating_layer_and_keyboard(self):
        power = (ROOT/'modules/power/PowerMenu.qml').read_text()
        shell = (ROOT/'shell.qml').read_text()
        context = (ROOT/'modules/main/ContextMenu.qml').read_text()
        self.assertIn('WlrLayer.Overlay', power)
        self.assertIn('Keys.onPressed', power)
        self.assertIn('Qt.Key_Down', power)
        self.assertIn('Qt.Key_Return', power)
        self.assertIn('Qt.Key_Escape', power)
        self.assertIn('confirmation !== action', power)
        self.assertIn('function power(): void', shell)
        self.assertIn('shell-power', context)

if __name__ == '__main__':
    unittest.main()
