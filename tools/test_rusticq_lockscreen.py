#!/usr/bin/env python3
"""Tests theme and safe OS integration without ever locking the test machine."""
from pathlib import Path
from unittest.mock import patch
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT/'scripts'/file)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

LOCK = load('rusticq_lock_test', 'rusticq-lockscreen.py')
POWER = load('rusticq_power_lock_test', 'rusticq-power-action.py')

class LockScreenTests(unittest.TestCase):
    def test_theme_has_real_authentication_and_accessible_password(self):
        config=LOCK.build_config({'accentName':'purple'})
        self.assertIn('input-field {',config)
        self.assertIn('text = $TIME',config)
        self.assertIn('text = $USER',config)
        self.assertIn('Authentication failed',config)
        self.assertIn('fade_on_empty = false',config)
        self.assertIn('color = rgb(d3869b)',config)
        self.assertNotIn('path = screenshot', config)
        self.assertNotIn('onclick',config)

    def test_unknown_accent_falls_back_to_original_orange(self):
        self.assertIn('color = rgb(d65d0e)',LOCK.build_config({'accentName':'unrecognized'}))

    def test_private_atomic_render(self):
        with tempfile.TemporaryDirectory() as base:
            home=Path(base)
            with patch.object(Path, 'home', return_value=home):
                conf=Path(LOCK.render())
                self.assertTrue(conf.exists())
                self.assertEqual(conf.stat().st_mode & 0o777,0o600)
                self.assertEqual(conf.parent.stat().st_mode & 0o777,0o700)
                self.assertIn('logo.png', conf.read_text())
                self.assertTrue((conf.parent/'logo.png').exists())
                LOCK.render()
                self.assertTrue(conf.exists())
                self.assertFalse((conf.parent/'hyprlock.tmp').exists())

    def test_refuses_symlinked_config_dir(self):
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as other:
            cache=Path(home)/'.cache'
            cache.symlink_to(other)
            with patch.object(Path,'home',return_value=Path(home)):
                with self.assertRaisesRegex(RuntimeError,'symlinked'):
                    LOCK.render()

    def test_wallpaper_validated_and_only_local(self):
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as other:
            image=Path(home)/'wallpaper.png'
            image.write_bytes(b'\x89PNG\r\n\x1a\n' + b'X'*100)
            with patch.object(Path, 'home', return_value=Path(home)):
                self.assertEqual(LOCK.image_path({'lockscreenBackground':'wallpaper', 'wallpaperPath':str(image)}),str(image))
                self.assertEqual(LOCK.image_path({'lockscreenBackground':'solid', 'wallpaperPath':str(image)}),'')
                self.assertEqual(LOCK.image_path({'lockscreenBackground':'wallpaper', 'wallpaperPath':str(image)+'\nexec = bad'}),'')
                self.assertEqual(LOCK.image_path({'lockscreenBackground':'wallpaper', 'wallpaperPath':str(Path(other)/'private.png')}),'')

    def test_cannot_claim_lock_when_hyprlock_missing(self):
        with patch.object(LOCK.shutil,'which',return_value=None):
            result=LOCK.lock()
        self.assertFalse(result['ok'])
        self.assertIn('not installed',result['message'])

    def test_spawns_hyprlock_with_private_conf(self):
        with patch.object(LOCK.shutil,'which',return_value='/usr/bin/hyprlock'), \
             patch.object(LOCK,'render',return_value='/tmp/theme.conf'), \
             patch.object(LOCK.subprocess,'Popen') as proc, \
             patch.object(LOCK.time,'sleep'), \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}):
            proc.return_value.poll.return_value=None
            result=LOCK.lock()
        self.assertTrue(result['ok'])
        self.assertEqual(proc.call_args.args[0],['/usr/bin/hyprlock','--config','/tmp/theme.conf'])
        self.assertTrue(proc.call_args.kwargs['start_new_session'])

    def test_power_menu_prepares_theme_and_launches_after_overlay_closes(self):
        with patch.object(POWER.shutil,'which', return_value='/usr/bin/hyprlock'), \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}), \
             patch.object(POWER.subprocess, 'run', return_value=subprocess.CompletedProcess([],0,'{"ok":true,"config":"/tmp/theme"}','')) as run, \
             patch.object(POWER.subprocess, 'Popen') as spawn:
            result=POWER.run('lock')
        self.assertTrue(result['ok'])
        self.assertIn('after the Power Menu closes', result['message'])
        self.assertIn('rusticq-native-lock.py',run.call_args.args[0][1])
        self.assertEqual(run.call_args.args[0][2], 'prepare')
        self.assertEqual(spawn.call_args.args[0][-1], '--start-rusticq-lock')
        self.assertTrue(spawn.call_args.kwargs['start_new_session'])
        with patch.object(POWER.time,'sleep') as delay, \
             patch.object(POWER.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'{"ok":true}','')) as start:
            self.assertEqual(POWER.start_rusticq_lock(),0)
        self.assertGreaterEqual(delay.call_args.args[0], .7)
        self.assertIn('rusticq-native-lock.py',start.call_args.args[0][1])
        self.assertEqual(start.call_args.args[0][2], 'start')
        with patch.object(POWER.shutil,'which',return_value='/usr/bin/omarchy-launch-screensaver'):
            self.assertEqual(POWER.action_command('screensaver'), ['omarchy-launch-screensaver','force'])

    def test_power_menu_refuses_default_fallback_and_render_errors(self):
        def which(name):
            return '/usr/bin/loginctl' if name=='loginctl' else None
        with patch.object(POWER.shutil,'which',side_effect=which):
            with self.assertRaisesRegex(RuntimeError,'Quickshell 0.3.1'):
                POWER.action_command('lock')
        with patch.object(POWER.shutil,'which',return_value='/usr/bin/hyprlock'), \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}), \
             patch.object(POWER.subprocess,'run',return_value=subprocess.CompletedProcess([],1,'{"ok":false,"message":"render failed"}','')) as run, \
             patch.object(POWER.subprocess,'Popen') as spawn:
            result=POWER.run('lock')
        self.assertFalse(result['ok'])
        self.assertIn('render failed',result['message'])
        spawn.assert_not_called()

    def test_qml_screen_and_shortcut_registration(self):
        theme=(ROOT/'modules/settings/pages/SettingsAppearancePage.qml').read_text()
        self.assertIn('RusticQ Lock Screen',theme)
        power_qml = (ROOT/'modules/power/PowerMenu.qml').read_text()
        self.assertIn('RusticQ Native Lock · WlSessionLock/PAM',power_qml)
        self.assertIn('rusticq-power-action.py',power_qml)
        self.assertIn('SettingsStore.lockscreenBackground',theme)
        store=(ROOT/'config/SettingsStore.qml').read_text()
        self.assertIn('lockscreenBackground: lockscreenBackground',store)
        self.assertIn('if (action === "lock")', (ROOT/'shell.qml').read_text())
        self.assertIn("'lock', \"name\": 'RusticQ lock screen'", (ROOT/'scripts/rustiq-desktop-integration.py').read_text())

if __name__=='__main__':
    unittest.main()
