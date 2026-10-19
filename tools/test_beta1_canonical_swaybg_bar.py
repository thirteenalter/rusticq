#!/usr/bin/env python3
"""Canonical Beta 1 regression: preserving full widgets and optional bar/memory."""
from pathlib import Path
import importlib.util
import json
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
STORE = (ROOT / 'config/SettingsStore.qml').read_text()


def qml_function(name):
    match = re.search(r'(?m)^    function ' + re.escape(name) + r'\([^\n]*\) \{', STORE)
    if not match:
        raise AssertionError(name)
    depth = 0
    for i in range(match.end()-1, len(STORE)):
        if STORE[i] == '{':
            depth += 1
        if STORE[i] == '}':
            depth -= 1
            if depth == 0:
                return STORE[match.start()+4:i+1]
    raise AssertionError('Unbalanced function: '+name)


class CanonicalBeta1(unittest.TestCase):
    def test_full_beta1_features_were_not_replaced_by_reduced_archive(self):
        required = (
            'modules/main/DesktopScratchpadCard.qml',
            'modules/main/DesktopRandomImageCard.qml',
            'modules/main/DesktopNotesCard.qml',
            'modules/main/WifiShareOverlay.qml',
            'modules/main/ShortcutBackupConfirmationWindow.qml',
            'modules/lock/RusticQLockSurface.qml',
            'lockscreen.qml',
            'scripts/rusticq-idle-memory.py',
            'scripts/rusticq-wifi-advanced.py',
            'scripts/rusticq-native-lock.py',
            'tools/test_shortcut_full_backup.py',
        )
        for rel in required:
            self.assertTrue((ROOT / rel).is_file(), rel)
        for function in ('widgetAllowedOnWorkspace', 'setWidgetWorkspace',
                         'workspaceNoteKey', 'widgetSize', 'setWidgetSize',
                         'widgetPosition', 'setWidgetPosition', 'workspaceNote',
                         'setWorkspaceNote'):
            self.assertIn('function ' + function + '(', STORE)
        self.assertIn('property var widgetWorkspaceScopes:', STORE)
        self.assertIn('property var workspaceNotes:', STORE)
        image=(ROOT/'modules/main/DesktopRandomImageCard.qml').read_text()
        self.assertIn('onActiveFolderChanged',image)
        self.assertNotIn('onWidgetImageFolderChanged',image)

    def test_store_preserves_legacy_positions_when_new_bar_icon_is_inserted(self):
        names = ('validateBarIconOrder', 'normalizeBarOrder', 'barOrder',
                 'setBarVisible', 'toggleBar')
        js = '\n'.join(qml_function(name) for name in names)
        program=r'''
const assert=require('node:assert/strict');
const barIconKeys=['rusticq','arch','launcher','menu','workspaces','weather','time','date',
'bluetooth','wifi','battery','audio','notifications','barToggle','task','quickModes','quickControl','mic','down','up'];
let barMode='separated', barIconOrderByMode={}, barVisible=true, saves=0;
function save(){saves++;}
__FUNCS__
const old=barIconKeys.filter(x=>x!=='barToggle');
const original=['wifi','battery',...old.filter(x=>x!=='wifi'&&x!=='battery')];
barIconOrderByMode.separated=original;
const merged=barOrder();
assert.equal(merged.length,barIconKeys.length);
assert.deepEqual(merged.filter(x=>x!=='barToggle'),original);
assert.equal(merged.indexOf('barToggle'),merged.indexOf('notifications')+1);
const preBell=original.filter(x=>x!=='notifications');
assert.equal(validateBarIconOrder(preBell),true);
barIconOrderByMode.simple=preBell;
assert.deepEqual(barOrder('simple').filter(x=>x!=='barToggle'&&x!=='notifications'),preBell);
setBarVisible(false);assert.equal(barVisible,false);
toggleBar();assert.equal(barVisible,true);
assert.equal(saves,2);
console.log('PASS preserved beta1 drag order across bar toggle migration');
'''.replace('__FUNCS__',js)
        res=subprocess.run(['node','-e',program],capture_output=True,text=True,timeout=10)
        self.assertEqual(res.returncode,0,res.stderr+res.stdout)

    def test_ui_shortcuts_deps_and_memory_controls(self):
        shell=(ROOT/'shell.qml').read_text()
        bar=(ROOT/'modules/main/Bar.qml').read_text()
        zone=(ROOT/'components/BarZone.qml').read_text()
        appearance=(ROOT/'modules/settings/pages/SettingsAppearancePage.qml').read_text()
        deps=json.loads((ROOT/'config/dependencies.json').read_text())
        self.assertIn('SettingsStore.toggleBar()',shell)
        self.assertIn('SettingsStore.setBarVisible(false)',shell)
        self.assertIn('BarRecoveryHandle { required property var modelData; screen: modelData }',shell)
        self.assertIn('visible: SettingsStore.barVisible',bar)
        self.assertIn('case "barToggle": return barTogglePart;',zone)
        self.assertIn('SettingsStore.wallpaperFitMode',appearance)
        self.assertIn('rusticq-idle-memory.py',appearance)
        self.assertIn('Set baseline',appearance)
        self.assertIn('!SettingsStore.lowMemoryShellMode || Store.aiVisible',shell)
        self.assertIn('wallpaperStartup.exec(args)',shell)
        self.assertTrue(any(x.get('package')=='swaybg' for x in deps['optional']))
        file=ROOT/'scripts/rustiq-desktop-integration.py'
        spec=importlib.util.spec_from_file_location('test_canonical_action_registry',file)
        obj=importlib.util.module_from_spec(spec);spec.loader.exec_module(obj)
        self.assertTrue(set(('bar-toggle','bar-show','bar-hide')).issubset(obj.ACTIONS))
        self.assertEqual(obj.BAR_ACTIONS['barToggle'],['bar-toggle','bar-show','bar-hide'])

if __name__=='__main__': unittest.main()
