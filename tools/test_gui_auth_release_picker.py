#!/usr/bin/env python3
"""Offline security/UX regression for AUR, Polkit, and release chooser.

Never executes pacman, yay, pkexec, curl, or any real package transaction.
"""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

def module(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

PKG = module('scripts/rustiq-package-manager.py', 'pkg_release_auth_test')
RELEASES = module('scripts/rusticq-shell-updates.py', 'releases_auth_test')

class Reply:
    def __init__(self, data): self.data=data
    def __enter__(self): return self
    def __exit__(self, exc_type, exc_value, tb): pass
    def read(self, size): return self.data[:size]

class PackageSafety(unittest.TestCase):
    def test_exact_aur_metadata_via_https_rpc_not_yay_preflight(self):
        response = json.dumps({'type':'multiinfo','results':[{'Name':'ventoy-bin'}]}).encode()
        with patch.object(PKG.urllib.request, 'urlopen', return_value=Reply(response)) as request:
            self.assertTrue(PKG.lookup_aur_package('ventoy-bin'))
        url = request.call_args.args[0].full_url
        self.assertTrue(url.startswith('https://aur.archlinux.org/rpc/v5/info?'))
        self.assertIn('ventoy-bin',url)
        self.assertNotIn('nocolor',url)

    def test_rejects_missing_and_mismatched_metadata(self):
        with patch.object(PKG.urllib.request, 'urlopen', return_value=Reply(b'{"results":[{"Name":"fake"}]}')):
            with self.assertRaisesRegex(RuntimeError, 'does not exist'):
                PKG.lookup_aur_package('ventoy-bin')
        with self.assertRaises(ValueError):
            PKG.lookup_aur_package('foo; rm -rf /')

    def test_yay_install_stays_unprivileged_with_native_polkit_for_pacman(self):
        executed=[]
        def runner(command, timeout=20):
            executed.append(command)
            if command[:2] == ['pacman', '-Qq']:
                return subprocess.CompletedProcess(command,0,'ventoy-bin','')
            return subprocess.CompletedProcess(command,0,'','')
        with patch.object(PKG.shutil, 'which', return_value='/usr/bin/yay'), \
             patch.object(PKG.os, 'geteuid', return_value=1000), \
             patch.object(PKG.Path, 'is_file', return_value=True), \
             patch.object(PKG, 'lookup_aur_package', return_value=True) as lookup, \
             patch.object(PKG, 'cmd_output', side_effect=runner):
            result=PKG.source_transaction('yay','install','ventoy-bin')
        self.assertTrue(result['ok'],result)
        lookup.assert_called_once_with('ventoy-bin')
        cmd=executed[0]
        self.assertEqual(cmd[:3],['yay','-S','--aur'])
        self.assertIn('--sudo',cmd)
        self.assertEqual(cmd[cmd.index('--sudo')+1],'/usr/bin/pkexec')
        self.assertNotIn('nocolor', ' '.join(cmd))
        self.assertNotIn('sudo',cmd[:2])
        self.assertNotIn('pkexec',cmd[:2])
        self.assertNotIn('rm',cmd)

    def test_yay_bad_nocolor_error_cleaned_and_not_declared_nonexistent(self):
        bad=subprocess.CompletedProcess([],1,'','\x1b[31minvalid option \'nocolor\'\x1b[0m')
        with patch.object(PKG.shutil,'which',return_value='/usr/bin/yay'), \
             patch.object(PKG.os,'geteuid',return_value=1000), \
             patch.object(PKG.Path,'is_file',return_value=True), \
             patch.object(PKG,'lookup_aur_package',return_value=True), \
             patch.object(PKG,'cmd_output',return_value=bad):
            with self.assertRaisesRegex(RuntimeError,'yay/pacman combination rejected') as err:
                PKG.source_transaction('yay','install','ventoy-bin')
        self.assertNotIn('\x1b',str(err.exception))

    def test_gui_uses_system_agent_and_no_password_capture(self):
        page=(ROOT/'modules/settings/pages/SettingsInfoPage.qml').read_text()
        dialog=(ROOT/'modules/main/PackageConfirmationWindow.qml').read_text()
        self.assertIn('packageAwaitingSystemAuth',page)
        self.assertIn('auth-capabilities',page)
        self.assertIn('Polkit password/fingerprint dialog',page)
        self.assertIn('not by RusticQ',page)
        self.assertIn('Credentials are never collected by this package confirmation window.', dialog)
        self.assertNotIn('sudo -S', page)

class GithubVersionPicker(unittest.TestCase):
    def test_version_data_includes_beta_and_stable(self):
        records=[dict(tag_name='beta-1',name='Beta 1',prerelease=True,draft=False,published_at='2026-10-01',
                      zipball_url='https://api.github.com/repos/thirteenalter/rusticq/zipball/beta-1',assets=[]),
                 dict(tag_name='v1.0.0',name='Stable 1',prerelease=False,draft=False,published_at='2026-10-10',
                      zipball_url='https://api.github.com/repos/thirteenalter/rusticq/zipball/v1.0.0',assets=[])]
        with patch.object(RELEASES,'curl_bytes',return_value=json.dumps(records).encode()):
            response=RELEASES.list_releases()
        self.assertEqual([item['tag'] for item in response['releases']],['beta-1','v1.0.0'])
        self.assertTrue(response['releases'][0]['danger'])
        self.assertFalse(response['releases'][1]['danger'])
        self.assertTrue(response['releases'][0]['available'])
        self.assertTrue(response['releases'][0]['source_archive'])

    def test_release_picker_is_real_data_driven_and_requires_ack(self):
        page=(ROOT/'modules/settings/pages/SettingsIntegrationPage.qml').read_text()
        for token in ('shellReleaseListProc','"releases"','shellReleaseOptions',
                      'releaseVersionsList','root.selectShellRelease(releaseEntry.modelData.tag)',
                      'BETA / RISK', 'shellReleaseMetadataMatches',
                      'shellUpdateRiskAccepted', 'Refresh versions',
                      'root.shellFetchVersions()', 'DANGER: this release'):
            self.assertIn(token,page, token)
        self.assertIn('root.shellUpdateConfirm === updateConfirmColumn.phrase',page)
        self.assertIn('(!shellReleaseTag.length || shellUpdateStatus.release.tag === shellReleaseTag)',page)

if __name__ == '__main__': unittest.main()
