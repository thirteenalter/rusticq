#!/usr/bin/env python3
"""Safe updater integration tests with isolated XDG paths and mocked GitHub.
No real network, package transaction, compositor or user directories affected.
"""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/rusticq-shell-updates.py'


def load():
    spec = importlib.util.spec_from_file_location('rusticq_shell_update_module', SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def create_source(path, value='original', *, user_settings=True):
    (path/'config').mkdir(parents=True)
    (path/'scripts').mkdir()
    (path/'modules/settings/pages').mkdir(parents=True)
    (path/'shell.qml').write_text('ShellRoot { // '+value+' }')
    (path/'config/SettingsStore.qml').write_text('pragma Singleton')
    (path/'scripts/rustiq-desktop-integration.py').write_text('# safe-'+value)
    (path/'modules/settings/pages/SettingsIntegrationPage.qml').write_text('Item {}')
    if user_settings: (path/'user-settings.json').write_text('{"saved":"old"}\n')


class Updates(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.m = load()
        self.home = self.base/'home'
        self.home.mkdir()
        self.target = self.home/'.local/share/rusticq/shell'
        self.local = self.home/'dev/quickshell'
        self.state = self.home/'.local/state/rusticq/shell-updates'
        self.manifest = self.home/'.local/state/rusticq/integration/manifest.json'
        self.manifest.parent.mkdir(parents=True)
        self.manifest.write_text(json.dumps({'installed_shell': str(self.target)}))
        create_source(self.target)
        create_source(self.local,'updated',user_settings=False)
        for name, value in [('SHELL',self.target),('LOCAL',self.local),('MANIFEST',self.manifest),('STATE_DIR',self.state),('STATE_FILE',self.state/'status.json'),('LOCK',self.state/'update.lock')]:
            p=patch.object(self.m,name,value); p.start(); self.addCleanup(p.stop)

    def test_local_reapply_backup_and_user_preferences(self):
        result = self.m.apply_update('local','REAPPLY LOCAL')
        self.assertTrue(result['ok'])
        self.assertEqual((self.target/'shell.qml').read_text(),'ShellRoot { // updated }')
        self.assertEqual((self.target/'user-settings.json').read_text(),'{"saved":"old"}\n')
        self.assertIn('original', (Path(result['backup'])/'shell.qml').read_text())
        self.assertEqual((self.local/'shell.qml').read_text(),'ShellRoot { // updated }')
        status=self.m.current_status()
        self.assertEqual(status['progress'],100)
        self.assertTrue(status['ready_for_next_login'])
        self.assertEqual(status['backups'],1)
        self.assertFalse(status['installed_tag'])

    def test_confirm_mandatory_and_failures_leave_install_intact(self):
        for source in ['local','github']:
            with self.assertRaisesRegex(self.m.UpdateError,'Type'):
                self.m.apply_update(source,'BAD')
        self.local.joinpath('shell.qml').unlink()
        with self.assertRaisesRegex(self.m.UpdateError,'missing source'):
            self.m.apply_update('local','REAPPLY LOCAL')
        self.assertIn('original',(self.target/'shell.qml').read_text())
        self.assertFalse(list(self.target.parent.glob('shell-before-update-*')))

    def test_rollback_restores_old_shell_and_keeps_pre_rollback_snapshot(self):
        result = self.m.apply_update('local','REAPPLY LOCAL')
        reversed_update = self.m.rollback('ROLLBACK SHELL')
        self.assertEqual(self.m.current_status()['state'],'installed')
        self.assertIn('original',self.target.joinpath('shell.qml').read_text())
        self.assertIn('updated',Path(reversed_update['backup']).joinpath('shell.qml').read_text())
        self.assertEqual((self.target/'user-settings.json').read_text(),'{"saved":"old"}\n')

    def test_rejects_symlink_and_manifest_mismatch(self):
        self.manifest.write_text('{"installed_shell":"/tmp/mystery"}')
        with self.assertRaisesRegex(self.m.UpdateError,'does not match'):
            self.m.apply_update('local','REAPPLY LOCAL')
        self.assertIn('original',self.target.joinpath('shell.qml').read_text())
        self.manifest.unlink()
        with self.assertRaisesRegex(self.m.UpdateError,'not installed'):
            self.m.apply_update('local','REAPPLY LOCAL')

    def make_zip(self, malicious=None):
        dest=self.base/'release.zip'
        with zipfile.ZipFile(dest,'w') as z:
            for rel in self.m.REQUIRED:
                z.writestr('quickshell/'+rel, '# good')
            if malicious:
                z.writestr(malicious, 'bad')
        return dest

    def test_rejects_zip_slip_and_patch_archive(self):
        for attack in ['quickshell/../../escape.sh','/etc/passwd','foreign/shell.qml']:
            z=self.make_zip(attack)
            with self.assertRaises(self.m.UpdateError):
                self.m.extract_full_zip(z,self.base/('stage-'+str(len(attack))))
        self.assertFalse((self.base/'escape.sh').exists())
        empty=self.base/'patch.zip'
        with zipfile.ZipFile(empty,'w') as z:
            z.writestr('quickshell/readme.md','PATCH')
        with self.assertRaisesRegex(self.m.UpdateError,'missing source'):
            self.m.extract_full_zip(empty,self.base/'patch-stage')
        self.assertIn('original',self.target.joinpath('shell.qml').read_text())

    def test_select_release_requires_full_archive(self):
        release={'tag_name':'beta-1','assets':[{'name':'custom-patch.zip','size':400,'state':'uploaded'}]}
        with self.assertRaisesRegex(self.m.UpdateError,'no full ZIP'):
            self.m.choose_full_asset(release)
        release['assets'].append({'name':'rusticq-beta-1-full.zip','size':100,'state':'uploaded','digest':'sha256:'+'0'*64})
        self.assertEqual(self.m.choose_full_asset(release)['name'],'rusticq-beta-1-full.zip')

    def test_github_full_release_install_mock_metadata_and_download(self):
        z=self.make_zip()
        digest=hashlib.sha256(z.read_bytes()).hexdigest()
        release={'tag_name':'beta-1','name':'Beta 1','assets':[{'name':'rusticq-beta1-full.zip','state':'uploaded','size':z.stat().st_size,'digest':'sha256:'+digest,'browser_download_url':'https://github.com/thirteenalter/rusticq/releases/download/beta-1/rusticq-beta1-full.zip'}]}
        asset=release['assets'][0]
        def download(r,a,destination):
            shutil.copy(z,destination)
            return self.m.verify_checksum(destination,r,a)
        with patch.object(self.m,'releases_get',return_value=release), patch.object(self.m,'download_release',side_effect=download):
            checked=self.m.check_updates('beta-1')
            self.assertEqual(checked['release']['asset'],asset['name'])
            self.assertFalse(checked['update_available']) # version unknown, not a definite newer build
            result=self.m.apply_update('github','UPDATE SHELL','beta-1')
            self.assertTrue(result['ok'])
        self.assertEqual(self.m.current_status()['installed_tag'],'beta-1')
        self.assertTrue((self.target/'user-settings.json').exists())
        self.assertEqual(self.m.current_status()['backups'],1)

    def test_post_rename_state_failure_is_rolled_back(self):
        save=self.m.state_save
        def fail_final(**kw):
            if kw.get('state') == 'installed':
                raise OSError('disk full for update status')
            return save(**kw)
        with patch.object(self.m,'state_save',side_effect=fail_final):
            with self.assertRaisesRegex(OSError,'disk full'):
                self.m.apply_update('local','REAPPLY LOCAL')
        self.assertIn('original',self.target.joinpath('shell.qml').read_text())
        self.assertFalse(list(self.target.parent.glob('shell-before-update-*')))

    def test_manual_tag_rejects_unexpected_characters(self):
        with self.assertRaisesRegex(self.m.UpdateError,'Invalid GitHub release tag'):
            self.m.releases_get('beta-1/../../different')

    def test_github_checksum_mismatch_prevents_install(self):
        z=self.make_zip()
        release={'tag_name':'beta-1','assets':[{'name':'rusticq-full.zip','state':'uploaded','size':z.stat().st_size,'digest':'sha256:'+'0'*64,'browser_download_url':'https://github.com/thirteenalter/rusticq/releases/download/beta-1/rusticq-full.zip'}]}
        with patch.object(self.m,'releases_get',return_value=release), patch.object(self.m,'download_release',side_effect=lambda r,a,d: (shutil.copy(z,d), self.m.verify_checksum(d,r,a))[-1]):
            with self.assertRaisesRegex(self.m.UpdateError,'checksum mismatch'):
                self.m.apply_update('github','UPDATE SHELL','beta-1')
        self.assertIn('original',self.target.joinpath('shell.qml').read_text())
        self.assertFalse(list(self.target.parent.glob('shell-before-update-*')))


if __name__=='__main__':
    unittest.main()
