#!/usr/bin/env python3
"""Dual-target GitHub update regression; no external network or live files touched."""
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
from unittest.mock import patch
import unittest
import importlib.util
import zipfile

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'scripts/rusticq-shell-updates.py'


def loaded():
    spec=importlib.util.spec_from_file_location('rusticq_dual_target',SCRIPT)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def make_tree(path, marker):
    for f in ['shell.qml','config/SettingsStore.qml','scripts/rustiq-desktop-integration.py','modules/settings/pages/SettingsIntegrationPage.qml']:
        (path/f).parent.mkdir(parents=True, exist_ok=True)
        (path/f).write_text(marker)


class Targets(unittest.TestCase):
    def setUp(self):
        tmp=tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        base=Path(tmp.name)
        self.m=loaded()
        self.dev=base/'dev/quickshell'
        self.shell=base/'share/rusticq/shell'
        self.integration=base/'state/rusticq/integration/manifest.json'
        self.state=base/'state/rusticq/shell-updates'
        self.integration.parent.mkdir(parents=True)
        make_tree(self.dev,'developer')
        for field, value in [('LOCAL',self.dev),('SHELL',self.shell),('MANIFEST',self.integration),('STATE_DIR',self.state),('STATE_FILE',self.state/'status.json'),('LOCK',self.state/'update.lock')]:
            active=patch.object(self.m,field,value);active.start();self.addCleanup(active.stop)

    def zip(self, marker, prefix='quickshell'):
        z=self.dev.parent / 'release.zip'
        with zipfile.ZipFile(z,'w') as f:
            for file in self.m.REQUIRED:
                f.writestr(prefix+'/'+file,marker)
        return z

    def test_check_github_after_omarchy_restore(self):
        rel={'tag_name':'beta-1','name':'Beta-1','assets':[{'name':'rusticq-full.zip','state':'uploaded','size':100,'digest':'sha256:'+'e'*64}]}
        with patch.object(self.m,'releases_get',return_value=rel):
            checked=self.m.check_updates('beta-1')
        self.assertTrue(checked['ok'])
        self.assertFalse(self.m.current_status()['installed'])
        self.assertTrue(self.m.current_status()['dev_ready'])

    def test_github_update_dev_without_permanent_then_rollback(self):
        archive=self.zip('github')
        digest=hashlib.sha256(archive.read_bytes()).hexdigest()
        release={'tag_name':'beta-1','assets':[{'name':'rusticq-full.zip','state':'uploaded','size':archive.stat().st_size,'digest':'sha256:'+digest}]}
        def download(_r,_a,dest):
            shutil.copyfile(archive,dest)
            return self.m.verify_checksum(dest,release,release['assets'][0])
        with patch.object(self.m,'releases_get',return_value=release),patch.object(self.m,'download_release',side_effect=download):
            result=self.m.apply_update('github','UPDATE SHELL','beta-1',target='dev')
        self.assertEqual(result['target'],'dev')
        self.assertEqual((self.dev/'shell.qml').read_text(),'github')
        self.assertEqual(self.m.current_status()['backups_dev'],1)
        self.assertEqual(self.m.current_status()['backups_installed'],0)
        result=self.m.rollback('ROLLBACK SHELL',target='dev')
        self.assertEqual(result['target'],'dev')
        self.assertEqual((self.dev/'shell.qml').read_text(),'developer')

    def test_independent_histories_and_reapply(self):
        make_tree(self.shell,'installed-old')
        self.integration.write_text(json.dumps({'installed_shell':str(self.shell)}))
        self.m.apply_update('local','REAPPLY LOCAL',target='installed')
        self.assertEqual(self.m.current_status()['backups_installed'],1)
        self.assertEqual(self.m.current_status()['backups_dev'],0)
        self.assertEqual((self.shell/'shell.qml').read_text(),'developer')
        self.m.rollback('ROLLBACK SHELL',target='installed')
        self.assertEqual((self.shell/'shell.qml').read_text(),'installed-old')

    def test_official_source_zip_is_not_claimed_sha_verified(self):
        url='https://api.github.com/repos/thirteenalter/rusticq/zipball/beta-1'
        rel={'tag_name':'beta-1','assets':[], 'zipball_url':url}
        asset=self.m.choose_full_asset(rel)
        self.assertTrue(asset['_source_archive'])
        self.assertFalse(self.m.release_summary(rel)['checksum_published'])
        archive=self.zip('github-source',prefix='thirteenalter-rusticq-deadbeef')
        out=self.dev.parent/'extract'
        self.m.extract_full_zip(archive,out,source_archive=True)
        self.assertEqual((out/'shell.qml').read_text(),'github-source')
        with self.assertRaises(self.m.UpdateError):
            self.m.extract_full_zip(archive,self.dev.parent/'not-source',source_archive=False)

    def test_unverified_asset_never_applied(self):
        bad=self.zip('bad')
        rel={'tag_name':'beta-1','assets':[{'name':'rusticq-full.zip','state':'uploaded','size':bad.stat().st_size,'digest':'sha256:'+'0'*64}]}
        with patch.object(self.m,'releases_get',return_value=rel), patch.object(self.m,'download_release',side_effect=lambda r,a,d: (shutil.copyfile(bad,d),self.m.verify_checksum(d,r,a))[-1]):
            with self.assertRaisesRegex(self.m.UpdateError,'checksum mismatch'):
                self.m.apply_update('github','UPDATE SHELL',target='dev')
        self.assertEqual((self.dev/'shell.qml').read_text(),'developer')
        self.assertEqual(self.m.current_status()['backups_dev'],0)

    def test_preserves_git_and_settings_when_updating_dev(self):
        (self.dev/'.git').mkdir()
        (self.dev/'.git/config').write_text('private repo origin')
        (self.dev/'user-settings.json').write_text('custom')
        arc=self.zip('github')
        digest=hashlib.sha256(arc.read_bytes()).hexdigest()
        rel={'tag_name':'beta-1','assets':[{'name':'rusticq-full.zip','state':'uploaded','size':arc.stat().st_size,'digest':'sha256:'+digest}]}
        with patch.object(self.m,'releases_get',return_value=rel),patch.object(self.m,'download_release',side_effect=lambda r,a,d:(shutil.copyfile(arc,d),digest)[-1]):
            self.m.apply_update('github','UPDATE SHELL',target='dev')
        self.assertEqual((self.dev/'.git/config').read_text(),'private repo origin')
        self.assertEqual((self.dev/'user-settings.json').read_text(),'custom')

if __name__=='__main__': unittest.main()
