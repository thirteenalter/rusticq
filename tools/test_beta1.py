"""Offline Beta 1 regressions. Does not touch real Hyprland or pacman."""
from pathlib import Path
import importlib.util
import io
import tempfile
import json
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

def load(rel, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / rel)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

D = load('scripts/rustiq-display.py', 'display_beta1')
P = load('scripts/rustiq-package-manager.py', 'packages_beta1')

MONITORS = [
    dict(name='eDP-1', mode='1920x1080@60.00', x=0, y=0, scale=1.0, width=1920, height=1080),
    dict(name='HDMI-A-1', mode='1920x1080@100.00', x=1920, y=0, scale=1.0, width=1920, height=1080),
]

class Beta1Tests(unittest.TestCase):
    def test_display_chooser_and_lua_geometry(self):
        valid = D.validate(MONITORS)
        self.assertEqual(len(valid), 2)
        self.assertIn('hl.monitor({ output = "HDMI-A-1"', D.make_lua(valid))
        self.assertIn('HDMI-A-1,1920x1080@100.00,1920x0,1', D.make_keyword_specs(valid))

    def test_reject_overlapping_monitors(self):
        raw = [dict(m) for m in MONITORS]
        raw[1]['x'] = 400
        with self.assertRaisesRegex(ValueError, 'overlap'):
            D.validate(raw)

    def test_refresh_rate_readback_not_falsely_successful(self):
        raw = D.validate(MONITORS)
        actual = {m['name']:dict(m,refreshRate=60) for m in raw}
        mismatch = D.mismatches_for(raw, actual)
        self.assertTrue(any('HDMI-A-1 refresh rate unchanged' in m for m in mismatch))
        actual['HDMI-A-1']['refreshRate'] = 100
        self.assertEqual(D.mismatches_for(raw, actual), [])

    def test_lua_apply_is_verifiable_not_silent_legacy_keyword(self):
        fake = {m['name']:dict(m,refreshRate=float(m['mode'].split('@')[1])) for m in MONITORS}
        with patch.object(D, 'apply_with_eval') as evaluate, patch.object(D, 'readback', return_value=fake):
            with patch.object(D.subprocess,'run',return_value=subprocess.CompletedProcess([],0,'hyprland lua','')):
                with patch.object(D.time,'sleep'):
                    with patch.object(sys,'argv',['rustiq-display.py','apply']),patch.object(sys,'stdin',io.StringIO(json.dumps(MONITORS) + "\n")):
                        result = D.main()
        self.assertTrue(result['ok'])
        self.assertFalse(result.get('pending', False))  # already-active draft needs no dispatch

    def test_graphical_app_owner_by_file_or_name(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'org.example.Foo.desktop'
            path.write_text('[Desktop Entry]\nName=Example Foo\nExec=examplefoo\n')
            response=subprocess.CompletedProcess([],0,'examplefoo-pkg\n','')
            with patch.object(P,'run',return_value=response) as pacman:
                self.assertEqual(P.resolve_desktop('org.example.Foo','Example Foo',[folder]), 'examplefoo-pkg')
                self.assertEqual(P.resolve_desktop('unknown','Example Foo',[folder]), 'examplefoo-pkg')
            self.assertEqual(pacman.call_args[0][0][:2], ['pacman','-Qqo'])

    def test_package_request_fails_without_authorized_package(self):
        with self.assertRaises(ValueError):
            P.validate_package('foo;rm -rf ~')
        with self.assertRaises(ValueError):
            P.validate_request('reinstall','foo')
        self.assertEqual(P.make_commands('remove','firefox'), [['sudo','pacman','-R','--','firefox']])

    def test_full_separate_confirmations_and_manage_resolver(self):
        store=(ROOT/'config/Store.qml').read_text()
        dialog=(ROOT/'modules/main/PackageConfirmationWindow.qml').read_text()
        info=(ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        self.assertIn('packageOperationConfirmed',store)
        self.assertIn('confirmationVisible',store)
        self.assertIn('FloatingWindow {',dialog)
        self.assertNotIn('WlrLayer.Overlay',dialog)
        self.assertIn('root.typed === Store.confirmationPackage',dialog)
        self.assertIn('root.resolveGraphicalApp(desktopAppRow.modelData)',info)
        self.assertNotIn('heading: root.pendingAction === "remove" ? "Confirm uninstall"',info)

    def test_launcher_and_audio_meters_are_real(self):
        launcher=(ROOT/'modules/main/MiniLauncher.qml').read_text()
        self.assertIn('Keys.onDownPressed',launcher)
        self.assertIn('Keys.onUpPressed',launcher)
        self.assertIn('Keys.onReturnPressed',launcher)
        self.assertIn('selectedIndex',launcher)
        audio=(ROOT/'modules/main/MiniAudio.qml').read_text()
        self.assertEqual(audio.count('PwNodePeakMonitor'),2)
        self.assertIn('outputPeak.peak',audio)
        self.assertIn('microphonePeak.peak',audio)
        self.assertIn('rustiq-audio-test.sh',audio)

    def test_modules_are_only_icon_preferences_page(self):
        bar=(ROOT/'modules/settings/pages/SettingsBarPage.qml').read_text()
        modules=(ROOT/'modules/settings/pages/SettingsModulesPage.qml').read_text()
        self.assertNotIn('heading: "Icon preferences',bar)
        self.assertIn('SettingsStore.copyVisibilityFromMode',modules)
        self.assertIn('function setModeIconVisible', (ROOT/'config/SettingsStore.qml').read_text())

    def test_local_and_piped_install_dry_runs(self):
        script=ROOT/'scripts/install.sh'
        subprocess.run(['bash','-n',str(script)],check=True)
        local=subprocess.run(['bash',str(script),'--dry-run'],capture_output=True,text=True,check=True)
        self.assertIn('no packages installed',local.stdout)
        piped=subprocess.run(['bash','-s','--','--dry-run'],input=script.read_text(),capture_output=True,text=True,check=True)
        self.assertIn('REMOTE DRY RUN',piped.stdout)
        self.assertIn('thirteenalter/rusticq/zip/refs/heads/main', script.read_text())

    def test_beta_readme_is_not_placeholder_url(self):
        readme=(ROOT/'README.md').read_text()
        self.assertIn('https://raw.githubusercontent.com/thirteenalter/rusticq/refs/heads/main/scripts/install.sh', readme)
        self.assertIn('rusticq-beta1-patch.zip', readme)
        self.assertTrue((ROOT/'changelog/BETA-1.md').exists())

if __name__=='__main__':
    unittest.main()
