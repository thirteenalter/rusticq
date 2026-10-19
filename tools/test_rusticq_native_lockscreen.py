#!/usr/bin/env python3
"""Offline tests only: cannot exercise actual PAM/Wayland auth in CI."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('rusticq_native_lock', ROOT/'scripts/rusticq-native-lock.py')
NATIVE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(NATIVE)


class NativeLockTests(unittest.TestCase):
    def test_dedicated_session_lock(self):
        qml = (ROOT/'lockscreen.qml').read_text()
        assert 'ShellRoot {' in qml
        assert 'WlSessionLock {' in qml
        assert 'locked: true' in qml
        assert 'RusticQLockSurface {' in qml
        assert 'PamContext {' in qml
        assert 'config: "login"' in qml
        self.assertEqual(qml.count('sessionLock.locked = false;'),1)
        success_branch = qml.index('if (result === PamResult.Success && sessionLock.secure)')
        unlock = qml.index('sessionLock.locked = false;')
        error_branch = qml.index('} else {', success_branch)
        self.assertLess(success_branch, unlock)
        self.assertLess(unlock,error_branch)
        self.assertIn('pendingSecret = ""',qml)
        self.assertIn('pam.respond(secret)',qml)
        self.assertIn('respond(secret)',qml)
        self.assertNotIn('WlrLayer.Overlay',qml)
        self.assertNotIn('loginctl unlock-session',qml)

    def test_surface_is_native_pam_and_password_hidden(self):
        qml=(ROOT/'modules/lock/RusticQLockSurface.qml').read_text()
        for token in ('WlSessionLockSurface {','TextInput.Password',
                      'clear(); // Wipe', 'surface.controller.submit',
                      'SettingsStore.lockscreenBackground','SettingsStore.wallpaperPath',
                      'Theme.accent'):
            self.assertIn(token,qml)
        self.assertNotIn('onClicked: sessionLock.locked = false',qml)
        self.assertNotIn('Quickshell.execDetached(["loginctl", "unlock-session"',qml)

    def test_launcher_preflight_fail_closed_without_wayland(self):
        with patch.object(NATIVE, 'quickshell_binary',return_value='/usr/bin/qs'), \
             patch.dict(os.environ, {'WAYLAND_DISPLAY':''}):
            with self.assertRaisesRegex(RuntimeError,'Wayland'):
                NATIVE.preflight()

    def test_launcher_checks_quickshell_version(self):
        result = subprocess.CompletedProcess([],0,'quickshell 0.3.0','')
        with patch.object(NATIVE,'quickshell_binary',return_value='/usr/bin/qs'), \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}), \
             patch.object(NATIVE.subprocess,'run',return_value=result):
            with self.assertRaisesRegex(RuntimeError,'0.3.1'):
                NATIVE.preflight()
        result.stdout='quickshell 0.3.1'
        with patch.object(NATIVE,'quickshell_binary',return_value='/usr/bin/qs'), \
             patch.dict(os.environ,{'WAYLAND_DISPLAY':'wayland-1'}), \
             patch.object(NATIVE.subprocess,'run',return_value=result):
            self.assertEqual(NATIVE.preflight(),'/usr/bin/qs')

    def test_status_is_nonmutating(self):
        result=NATIVE.status()
        self.assertEqual(result['backend'],'Quickshell WlSessionLock + PAM')
        self.assertIn('fallback',result)

    def test_launcher_runtime_dir_is_private(self):
        with tempfile.TemporaryDirectory() as t:
            env={'XDG_RUNTIME_DIR':t}
            with patch.dict(os.environ,env):
                directory=NATIVE.secure_dir()
                self.assertTrue(directory.is_dir())
                self.assertEqual(directory.stat().st_mode & 0o777,0o700)

    def test_launcher_refuses_symlink(self):
        with tempfile.TemporaryDirectory() as t:
            Path(t,'rusticq-native-lock').symlink_to(Path(t))
            with patch.dict(os.environ,{'XDG_RUNTIME_DIR':t}):
                with self.assertRaisesRegex(RuntimeError,'symlinked'):
                    NATIVE.secure_dir()

    def test_power_menu_uses_native_and_keeps_omarchy_ascii(self):
        qml=(ROOT/'modules/power/PowerMenu.qml').read_text()
        action=(ROOT/'scripts/rusticq-power-action.py').read_text()
        self.assertIn('RusticQ Native Lock · WlSessionLock/PAM',qml)
        self.assertIn('PanelWindow {',qml)
        self.assertIn('WlrLayer.Overlay',qml)
        self.assertIn('omarchy-launch-screensaver',action)
        self.assertIn('rusticq-native-lock.py',action)
        self.assertIn("'prepare'",action)
        self.assertIn("'start'",action)
        self.assertNotIn("'rusticq-lockscreen.py'",action)

    def test_shortcut_and_settings_use_native(self):
        shell=(ROOT/'shell.qml').read_text()
        appearance=(ROOT/'modules/settings/pages/SettingsAppearancePage.qml').read_text()
        self.assertIn('scripts/rusticq-native-lock.py',shell)
        self.assertIn('scripts/rusticq-native-lock.py',appearance)
        self.assertNotIn('scripts/rusticq-lockscreen.py',appearance)
        self.assertIn('onClicked',appearance)

    def test_no_legacy_pam_overwrite(self):
        for relative in ('scripts/rusticq-native-lock.py','lockscreen.qml',
                         'modules/lock/RusticQLockSurface.qml'):
            self.assertNotIn('pam_unix.so', (ROOT/relative).read_text())
        self.assertNotIn('install.sh', (ROOT/'scripts/rusticq-native-lock.py').read_text())


if __name__=='__main__': unittest.main()
