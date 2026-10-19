#!/usr/bin/env python3
"""User-settings export, inspect, safe import, and QML integration tests.

All files are temporary. Never reads live user settings or modifies a session.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('rusticq_guard_transfer', ROOT/'scripts/rusticq-config-guard.py')
MOD=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MOD)

class TransferTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.base=Path(self.tmp.name)
        self.home=self.base/'home'; self.home.mkdir()
        self.project=self.home/'dev/quickshell'; self.project.mkdir(parents=True)
        self.path=self.project/'user-settings.json'
        self.original={'barMode':'compact','showNotifications':True,'wallpaperBackend':'swaybg',
                       'workspaceNotes':{'workspace:1':'My private note'},'aiApiKey':'should-never-export'}
        self.path.write_text(json.dumps(self.original)+'\n')
        self.guard=MOD.Guard(self.project,self.home/'.local/state')

    def test_save_and_load_with_snapshot_and_checksums(self):
        with patch.object(MOD.Path,'home',return_value=self.home):
            exported=self.guard.portable_export()
        target=Path(exported['path'])
        self.assertEqual(target.stat().st_mode & 0o777,0o600)
        self.assertEqual(target.parent.stat().st_mode & 0o777,0o700)
        self.assertEqual(target.name.startswith('rusticq-settings-'),True)
        package=json.loads(target.read_text())
        self.assertEqual(package['version'],1)
        self.assertNotIn('aiApiKey',package['settings'])
        self.assertEqual(package['settings']['workspaceNotes'],self.original['workspaceNotes'])
        preview=self.guard.portable_inspect(str(target))
        self.assertEqual(preview['format'],'RusticQ portable export')
        self.path.write_text('{"barMode":"simple","widgetPositions":{"clock":{"x":25}}}\n')
        with self.assertRaisesRegex(ValueError,'confirmation'):
            self.guard.portable_import(str(target),'',preview['sha256'])
        self.assertEqual(json.loads(self.path.read_text())['barMode'],'simple')
        result=self.guard.portable_import(str(target),'IMPORT SETTINGS',preview['sha256'])
        self.assertEqual(result['backup_id'] is not None,True)
        self.assertEqual(json.loads(self.path.read_text())['barMode'],'compact')
        self.assertNotIn('aiApiKey',json.loads(self.path.read_text()))
        snapshot=self.guard.target_dir('settings')/(result['backup_id']+'.json')
        self.assertEqual(json.loads(snapshot.read_text())['barMode'],'simple')
        self.assertEqual(self.guard.status()['settings']['snapshots'],1)
        self.assertEqual(self.guard.portable_inspect(str(target))['sha256'],result['sha256'])

    def test_legacy_plain_settings_import(self):
        candidate=self.base/'older-settings.json'; candidate.write_text('{"barMode":"professional","desktopNotes":true}')
        report=self.guard.portable_inspect(str(candidate))
        self.assertEqual(report['format'],'Legacy user-settings.json')
        changed=self.guard.portable_import(str(candidate),'IMPORT SETTINGS',report['sha256'])
        self.assertTrue(changed['backup_id'])
        self.assertEqual(json.loads(self.path.read_text())['barMode'],'professional')

    def test_modified_after_preview_cannot_import(self):
        candidate=self.base/'test.json'; candidate.write_text('{"barMode":"clean-compact"}')
        before=self.guard.portable_inspect(str(candidate))
        old=self.path.read_bytes()
        candidate.write_text('{"barMode":"simple"}')
        with self.assertRaisesRegex(ValueError,'changed since preview'):
            self.guard.portable_import(str(candidate),'IMPORT SETTINGS',before['sha256'])
        self.assertEqual(old,self.path.read_bytes())
        self.assertEqual(self.guard.versions('settings'),[])

    def test_reject_invalid_import_or_symlinks_no_mutation(self):
        before=self.path.read_bytes()
        for text in ('not json','[1,2]','{"__proto__":{"x":3}}','{"nested":{"constructor":4}}','{"value":NaN}'):
            candidate=self.base/'invalid.json'; candidate.write_text(text)
            with self.assertRaises((ValueError,json.JSONDecodeError)):
                self.guard.portable_inspect(str(candidate))
        symlink=self.base/'symlink.json'; symlink.symlink_to(self.path)
        with self.assertRaisesRegex(ValueError,'symlink'):
            self.guard.portable_inspect(str(symlink))
        candidate=self.base/'future.json'
        candidate.write_text('{"format":"rusticq-user-settings","version":200,"settings":{"barMode":"simple"}}')
        with self.assertRaisesRegex(ValueError,'version'):
            self.guard.portable_inspect(str(candidate))
        self.assertEqual(before,self.path.read_bytes())
        self.assertEqual(self.guard.versions('settings'),[])

    def test_existing_source_guard_and_ui_actions(self):
        page=(ROOT/'modules/settings/pages/SettingsIntegrationPage.qml').read_text()
        self.assertIn('heading: "User settings · Save / Load"',page)
        self.assertIn('settingsTransfer("export")',page)
        self.assertIn('SettingsStore.save(); settingsExportDelay.restart();',page)
        self.assertIn('settingsTransfer("inspect")',page)
        self.assertIn('settingsTransfer("import")',page)
        self.assertIn('settingsImportConfirmation === "IMPORT SETTINGS"',page)
        self.assertIn('settingsImportPreview.sha256',page)
        self.assertIn('"pick-settings"',page)
        self.assertIn('root.invalidateSettingsPreview()',page)
        script=(ROOT/'scripts/rusticq-appearance.py').read_text()
        self.assertIn("if args.action == 'pick-settings':",script)
        self.assertTrue((ROOT/'config/SettingsStore.qml').is_file())

    def test_cli_can_export_and_inspect_private_root(self):
        helper_path=self.project/'scripts/rusticq-config-guard.py'
        helper_path.parent.mkdir(exist_ok=True)
        helper_path.write_bytes((ROOT/'scripts/rusticq-config-guard.py').read_bytes())
        env={**os.environ,'HOME':str(self.home),'XDG_STATE_HOME':str(self.home/'.local/state')}
        def call(*params):
            result=subprocess.run(['python3',str(helper_path),*params],env=env,capture_output=True,text=True,timeout=10)
            return result.returncode,json.loads(result.stdout)
        code,export=call('export')
        self.assertEqual(code,0,export)
        code,report=call('inspect','--path',export['data']['path'])
        self.assertEqual(code,0,report)
        code,imported=call('import','--path',export['data']['path'],'--confirm','IMPORT SETTINGS','--sha256',report['data']['sha256'])
        self.assertEqual(code,0,imported)
        self.assertIn('backup_id',imported['data'])
        code,status=call('status')
        self.assertEqual(status['data']['settings']['snapshots'],1)

if __name__=='__main__': unittest.main()
