#!/usr/bin/env python3
"""Offline backend/QML contracts for advanced Wi-Fi and reversible Lua overrides."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
WIFI = ROOT / 'scripts/rusticq-wifi-advanced.py'
SHORT = ROOT / 'scripts/rustiq-desktop-integration.py'


def load_wifi():
    spec = importlib.util.spec_from_file_location('rusticq_wifi_test', WIFI)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class WifiAndShortcutTests(unittest.TestCase):
    def test_status_fields_secrets_never_returned(self):
        wifi = load_wifi()
        calls = []
        def fake_nm(*args, **kwargs):
            calls.append(args)
            if 'connection' in args and '--active' in args:
                return '00000000-0000-0000-0000-000000000001:wifi:wlan0'
            if '802-11-wireless.ssid' in args: return 'Home LAN'
            if 'ipv4.dns' in args: return ''
            if 'ipv4.method' in args: return 'auto'
            if 'ipv4.ignore-auto-dns' in args: return 'no'
            if 'IP4.DNS' in args: return '1.1.1.1\n8.8.8.8'
            if 'IP4.GATEWAY' in args: return '192.168.1.1'
            if 'IP4.ADDRESS' in args: return '192.168.1.10/24'
            return ''
        with patch.object(wifi, 'nm', side_effect=fake_nm):
            output = wifi.active_status()
        self.assertEqual(output['ssid'], 'Home LAN')
        self.assertEqual(output['dns'], '1.1.1.1, 8.8.8.8')
        self.assertNotIn('password', json.dumps(output).lower())
        self.assertEqual(output['interface'], 'wlan0')
        self.assertEqual(wifi.escape_wifi('Test;,:\\"'), 'Test\\;\\,\\:\\\\\\"')

    def test_wifi_qr_is_private_and_secret_not_json(self):
        wifi = load_wifi()
        with tempfile.TemporaryDirectory() as d:
            base = Path(d); base.chmod(0o700)
            with patch.dict(os.environ, {'XDG_RUNTIME_DIR': d}):
                with patch.object(wifi, 'active_wifi', return_value=('00000000-0000-0000-0000-000000000001','wlan0')):
                    def fake_value(uid, field, secret=False):
                        return {'802-11-wireless.ssid':'A;Cafe', '802-11-wireless-security.key-mgmt':'wpa-psk',
                                '802-11-wireless-security.psk':'private-password!'}[field]
                    def fake_encode(args, **kwargs):
                        self.assertEqual(kwargs['input'], 'WIFI:T:WPA;S:A\\;Cafe;P:private-password!;;')
                        self.assertNotIn('private-password!', repr(args))
                        Path(args[args.index('-o')+1]).write_bytes(b'PNG')
                        return type('P', (), {'returncode': 0})()
                    with patch.object(wifi, 'value', side_effect=fake_value), patch.object(wifi.shutil, 'which', return_value='/usr/bin/qrencode'), patch.object(wifi.subprocess, 'run', side_effect=fake_encode):
                        output = wifi.make_qr()
                    self.assertTrue(Path(output['path']).exists())
                    self.assertNotIn('private-password!', json.dumps(output))
                    self.assertEqual(Path(output['path']).stat().st_mode & 0o777, 0o600)
                    wifi.clear_qr()
                    self.assertFalse(Path(output['path']).exists())

    def test_dns_explicit_no_shell_and_reapply(self):
        wifi=load_wifi()
        calls=[]
        def nm(*args, **kwargs):
            calls.append(args)
            if 'ipv4.dns' in args and 'modify' not in args: return '8.8.8.8'
            if 'ipv4.ignore-auto-dns' in args and 'modify' not in args: return 'no'
            return ''
        with patch.object(wifi, 'active_wifi', return_value=('00000000-0000-0000-0000-000000000001','wlan0')):
            with patch.object(wifi,'nm',side_effect=nm):
                self.assertTrue(wifi.dns_change('dns-manual','1.1.1.1, 1.0.0.1')['ok'])
                self.assertIn(('device','reapply','wlan0'), calls)
                self.assertIn('1.1.1.1 1.0.0.1', str(calls))
                with self.assertRaises(ValueError): wifi.dns_change('dns-manual','$(touch /tmp/bad)')

    def test_shortcut_override_backup_revert_sensitive_key(self):
        with tempfile.TemporaryDirectory() as d:
            base=Path(d);home=base/'home';hypr=home/'.config/hypr';hypr.mkdir(parents=True)
            original='-- personal\no.bind("SUPER + ESCAPE", "Old recovery", "echo old")\n'
            bindings=hypr/'bindings.lua';bindings.write_text(original)
            env={**os.environ,'HOME':str(home),'XDG_CONFIG_HOME':str(home/'.config'),
                 'XDG_STATE_HOME':str(home/'.state'),'XDG_DATA_HOME':str(home/'.data'),'OMARCHY_PATH':str(base/'omarchy')}
            env.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
            def cli(*args):
                p=subprocess.run(['python3',str(SHORT),*args],capture_output=True,text=True,env=env)
                self.assertTrue(p.stdout,(args,p.stderr))
                data=json.loads(p.stdout)
                self.assertEqual(p.returncode,0,(args,data))
                return data
            cli('shortcut','--key','SUPER + ESCAPE','--action','power')
            configured=bindings.read_text()
            self.assertIn('o.bind("SUPER + ESCAPE", "RusticQ Power menu"',configured)
            self.assertIn('o.bind("SUPER + ESCAPE", "Old recovery"',configured)
            state=home/'.state/rusticq/integration'
            self.assertEqual((state/'shortcut-original.txt').read_text(),original)
            audit=(state/'shortcut-line-backups.json').read_text()
            self.assertIn('Old recovery',audit)
            cli('shortcut-revert','--action','power')
            self.assertEqual(bindings.read_text(),original)
            self.assertTrue((state/'shortcut-original.txt').exists())
            self.assertEqual((state/'shortcut-line-backups.json').read_text(),audit)

    def test_qml_layout_and_privacy(self):
        bar=(ROOT/'modules/bar/BarWifi.qml').read_text()
        popup=(ROOT/'modules/main/IndicatorPopup.qml').read_text()
        wifi=(ROOT/'modules/bar/WifiAdvanced.qml').read_text()
        audio=(ROOT/'modules/main/MiniAudio.qml').read_text()
        settings=(ROOT/'modules/settings/pages/SettingsShortcutsPage.qml').read_text()
        self.assertIn('WifiAdvanced {',bar)
        self.assertIn('Layout.preferredHeight: visible ? implicitHeight : 0',bar)
        self.assertNotIn('Layout.preferredHeight: visible ? 335 : 0',bar)
        self.assertIn('kind === "wifi"',popup)
        self.assertIn('Theme.sectionPadding',audio)
        self.assertIn('Store.requestShortcutConfirmation',settings)
        self.assertIn('onShortcutBackupApproved',settings)
        self.assertIn('create-shortcut-backup',settings)
        self.assertIn('root.shareQrRequested(screen, ssid)',wifi)
        self.assertIn('function beginWifiQr(screen, ssid)', popup)
        self.assertNotIn('qrLifetime',wifi)
        overlay=(ROOT/'modules/main/WifiShareOverlay.qml').read_text()
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay', overlay)
        self.assertIn('interval: 1000', overlay)
        self.assertIn('secondsRemaining: 45', overlay)
        self.assertIn('cleanupPending', overlay)
        self.assertIn('qrClear', overlay)
        self.assertIn('dns-manual',wifi)
        self.assertNotIn('password',json.dumps([x for x in ('snapshot','rxBytes','txBytes')]))


if __name__=='__main__':
    unittest.main()
