#!/usr/bin/env python3
"""Offline hidden Wi-Fi validation, activation rollback and secret transport."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('wifi_hidden', ROOT / 'scripts/rusticq-wifi-hidden.py')
WIFI = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(WIFI)


class HiddenWifiTests(unittest.TestCase):
    def request(self, **changes):
        return dict(ssid=' Hidden; $(echo test) ', interface='wlan0',
                    security='wpa-psk', password=' secret:$`\\value ', **changes)

    def test_password_only_in_inherited_memory_descriptor(self):
        calls = []
        descriptors = []
        request = self.request()

        def run(args, **options):
            calls.append(args)
            self.assertNotIn(request['password'], repr(args))
            self.assertNotIn('shell', options)
            stdout = ''
            if 'GENERAL.TYPE' in args:
                stdout = 'wifi\n'
            elif 'radio' in args:
                stdout = 'enabled\n'
            elif 'up' in args:
                fd, = options['pass_fds']
                descriptors.append(fd)
                self.assertEqual(args[args.index('passwd-file') + 1], f'/proc/self/fd/{fd}')
                self.assertEqual(os.read(fd, 1024).decode(),
                                 '802-11-wireless-security.psk:' + request['password'] + '\n')
            return subprocess.CompletedProcess(args, 0, stdout, '')

        with patch.object(WIFI.shutil, 'which', return_value='/usr/bin/nmcli'), \
                patch.object(WIFI.subprocess, 'run', side_effect=run):
            result = WIFI.connect_hidden(request)
        self.assertTrue(result['ok'])
        self.assertNotIn(request['password'], json.dumps(result))
        added = next(c for c in calls if 'add' in c)
        self.assertEqual(added[added.index('ssid') + 1], request['ssid'])
        self.assertEqual(added[added.index('802-11-wireless.hidden') + 1], 'yes')
        self.assertEqual(added[added.index('save') + 1], 'no')
        self.assertEqual(calls[-1][-2:], ['connection.autoconnect', 'yes'])
        self.assertFalse(any('delete' in call for call in calls))
        for fd in descriptors:
            with self.assertRaises(OSError):
                os.fstat(fd)

    def test_failed_activation_removes_only_new_uuid(self):
        calls = []
        def nm(*args, **options):
            calls.append(args)
            if 'GENERAL.TYPE' in args: return 'wifi'
            if 'radio' in args: return 'enabled'
            if 'up' in args: raise WIFI.WifiError('Connection failed')
            return ''
        with patch.object(WIFI.shutil, 'which', return_value='/usr/bin/nmcli'), \
                patch.object(WIFI, 'nm', side_effect=nm):
            with self.assertRaisesRegex(WIFI.WifiError, 'Connection failed'):
                WIFI.connect_hidden(self.request())
        added = next(c for c in calls if 'add' in c)
        uid = added[added.index('connection.uuid') + 1]
        self.assertEqual(calls[-1], ('connection', 'delete', 'uuid', uid))
        self.assertFalse(any('modify' in call for call in calls))

    def test_open_has_no_password_and_wpa3_uses_sae(self):
        for security in ('open', 'sae'):
            calls = []
            def nm(*args, **options):
                calls.append((args, options))
                if 'GENERAL.TYPE' in args: return 'wifi'
                if 'radio' in args: return 'enabled'
                return ''
            request = self.request()
            request['security'] = security
            with patch.object(WIFI.shutil, 'which', return_value='/usr/bin/nmcli'), \
                    patch.object(WIFI, 'nm', side_effect=nm):
                self.assertTrue(WIFI.connect_hidden(request)['ok'])
            added = next(args for args, _ in calls if 'add' in args)
            activated = next((args, options) for args, options in calls if 'up' in args)
            self.assertEqual('passwd-file' in activated[0], security != 'open')
            self.assertEqual('802-11-wireless-security.key-mgmt' in added, security != 'open')
            if security == 'sae': self.assertIn('sae', added)

    def test_invalid_requests_never_contact_networkmanager(self):
        for change in ({'ssid': ''}, {'ssid': 'é' * 17}, {'ssid': 'bad\nname'},
                       {'interface': '../wlan0'}, {'security': 'wpa-eap'},
                       {'password': 'short'}, {'password': 'secret\nmore'},
                       {'password': 'g' * 64}, {'password': None}):
            request = self.request()
            request.update(change)
            with patch.object(WIFI, 'nm') as nm:
                with self.assertRaises(WIFI.WifiError, msg=str(change)):
                    WIFI.connect_hidden(request)
                nm.assert_not_called()
        request = self.request()
        request.update(ssid='é' * 16, password='a' * 64)
        self.assertEqual(WIFI.validate(request)[0], request['ssid'])

    def test_missing_adapter_disabled_radio_and_missing_nmcli(self):
        for kind, radio in [('ethernet', 'enabled'), ('wifi', 'disabled')]:
            def nm(*args, **options):
                return kind if 'GENERAL.TYPE' in args else radio
            with patch.object(WIFI.shutil, 'which', return_value='/usr/bin/nmcli'), \
                    patch.object(WIFI, 'nm', side_effect=nm):
                with self.assertRaises(WIFI.WifiError): WIFI.connect_hidden(self.request())
        with patch.object(WIFI.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(WIFI.WifiError, 'nmcli is required'):
                WIFI.connect_hidden(self.request())

    def test_errors_do_not_echo_nmcli_output(self):
        process = subprocess.CompletedProcess([], 4, 'private-password', 'private-password')
        with patch.object(WIFI.subprocess, 'run', return_value=process):
            with self.assertRaises(WIFI.WifiError) as result: WIFI.nm('test')
        self.assertNotIn('private-password', str(result.exception))
        with patch.object(WIFI.subprocess, 'run', side_effect=subprocess.TimeoutExpired(['nmcli'], 45)):
            with self.assertRaisesRegex(WIFI.WifiError, 'timed out'): WIFI.nm('test')

    def test_json_errors_are_structured_without_tracebacks(self):
        for payload in ('not-json\n', '[]\n', '{"password": "private-password"}\n'):
            output = io.StringIO()
            with patch.object(WIFI.sys, 'stdin', io.StringIO(payload)), contextlib.redirect_stdout(output):
                self.assertEqual(WIFI.main(), 1)
            result = json.loads(output.getvalue())
            self.assertFalse(result['ok'])
            self.assertNotIn('private-password', output.getvalue())


if __name__ == '__main__':
    unittest.main()
