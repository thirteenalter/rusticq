#!/usr/bin/env python3
"""Beta 3 versioning and downgraded-release protection, fully offline."""
import importlib.util
from pathlib import Path
import json
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load_updater():
    spec = importlib.util.spec_from_file_location('beta3_update', ROOT/'scripts/rusticq-shell-updates.py')
    obj = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(obj)
    return obj


class Versioning(unittest.TestCase):
    def test_version_metadata_ui_and_docs(self):
        tag=(ROOT/'VERSION').read_text().strip()
        self.assertEqual(tag,'beta-3')
        meta=(ROOT/'config/ReleaseInfo.qml').read_text()
        self.assertIn('readonly property string tag: "'+tag+'"',meta)
        self.assertIn('readonly property string displayName: "Beta 3"',meta)
        self.assertIn('singleton ReleaseInfo 1.0 ReleaseInfo.qml',(ROOT/'config/qmldir').read_text())
        for name in ('modules/settings/SettingsWindow.qml','modules/settings/pages/SettingsAboutPage.qml'):
            content=(ROOT/name).read_text()
            self.assertIn('ReleaseInfo.displayName',content)
            self.assertNotRegex(content,r'BETA 1|Beta 1')
        self.assertIn('Beta 3',(ROOT/'README.md').read_text().split('## Beta 1')[0])
        self.assertTrue((ROOT/'changelog/BETA-3.md').is_file())

    def test_cli_version_is_local_and_not_published_claim(self):
        process=subprocess.run([sys.executable,str(ROOT/'scripts/rusticq-cli.py'),'version'],capture_output=True,text=True,timeout=10)
        self.assertEqual(process.returncode,0,process.stderr)
        result=json.loads(process.stdout)
        self.assertEqual(result['result']['tag'],'beta-3')
        self.assertEqual(result['result']['published_to_github'],'not_verified')

    def test_local_source_version_and_target_specific_comparison(self):
        m=load_updater()
        with tempfile.TemporaryDirectory() as d:
            base=Path(d)
            dev=base/'dev'; dev.mkdir()
            permanent=base/'installed'; permanent.mkdir()
            (dev/'VERSION').write_text('beta-3\n')
            (permanent/'VERSION').write_text('beta-2\n')
            (dev/'shell.qml').write_text('ShellRoot {}')
            (permanent/'shell.qml').write_text('ShellRoot {}')
            state=base/'state.json'; sd=base/'state'
            with patch.object(m,'LOCAL',dev),patch.object(m,'SHELL',permanent),patch.object(m,'STATE_FILE',state),patch.object(m,'STATE_DIR',sd):
                status=m.current_status()
                self.assertEqual(status['dev_tag'],'beta-3')
                self.assertEqual(status['source_version'],'beta-3')
                self.assertFalse(status['installed'])
                self.assertEqual(m.effective_version('installed'),'beta-2')
                self.assertEqual(m.version_relation('beta-1','beta-3'),-1)
                self.assertEqual(m.version_relation('beta-3','beta-3'),0)
                self.assertEqual(m.version_relation('beta-4','beta-3'),1)
                self.assertIsNone(m.version_relation('v1.0','beta-3'))
                release={'tag_name':'beta-1','name':'Beta 1', 'prerelease':True,
                         'assets':[{'name':'rusticq-full.zip','size':1234,'state':'uploaded','digest':'sha256:'+'a'*64}]}
                with patch.object(m,'releases_get',return_value=release):
                    result=m.check_updates('beta-1',target='dev')
                    self.assertFalse(result['update_available'])
                    self.assertTrue(result['downgrade'])
                    self.assertTrue(result['release']['downgrade'])
                    self.assertIn('OLDER',result['message'])
                    result2=m.check_updates('beta-1',target='installed')
                    self.assertTrue(result2['downgrade'])
                    self.assertEqual(result2['installed_tag'],'beta-2')
                    newer=dict(release,tag_name='beta-4',name='Beta 4')
                    with patch.object(m,'releases_get',return_value=newer):
                        result3=m.check_updates('beta-4',target='dev')
                        self.assertTrue(result3['update_available'])
                        self.assertFalse(result3['downgrade'])

    def test_no_rewrite_of_historical_betas(self):
        self.assertTrue((ROOT/'changelog/BETA-1.md').is_file())
        self.assertIn('Beta 1',(ROOT/'changelog/BETA-1.md').read_text())

if __name__=='__main__': unittest.main()
