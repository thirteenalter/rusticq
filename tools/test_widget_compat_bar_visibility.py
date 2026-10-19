#!/usr/bin/env python3
"""Offline regressions: missing SettingsStore widget API and recoverable bar toggle."""
from pathlib import Path
import importlib.util
import json
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
store = (ROOT / 'config/SettingsStore.qml').read_text()

def func(name):
    found = re.search(r'(?m)^    function ' + re.escape(name) + r'\([^\n]*\) \{',store)
    if not found: raise AssertionError('Missing QML function '+name)
    depth = 0
    for i in range(found.end()-1,len(store)):
        if store[i]=='{': depth+=1
        if store[i]=='}':
            depth-=1
            if depth==0: return store[found.start()+4:i+1]
    raise AssertionError('Unbalanced function '+name)

class WidgetCompat(unittest.TestCase):
    def test_runtime_missed_functions_and_property_signal_exist(self):
        for name in ['workspaceNoteKey','widgetAllowedOnWorkspace','widgetSize']:
            self.assertIn('function '+name+'(',store)
        # A QML property automatically generates its corresponding Changed signal
        self.assertIn('property string widgetImageFolder:',store)
        self.assertIn('widgetImageFolder: widgetImageFolder',store)
        self.assertIn('data.widgetImageFolder',store)
        self.assertIn('widgetSizes: widgetSizes',store)
        self.assertIn('widgetWorkspaceRules: widgetWorkspaceRules',store)
        self.assertIn('workspaceNotes: workspaceNotes',store)

    def test_widget_js_layout_workspace_storage(self):
        names=['workspaceNoteKey','widgetKey','widgetSize','setWidgetSize',
               'widgetAllowedOnWorkspace','setWidgetWorkspaces','workspaceNote','setWorkspaceNote',
               'setWidgetImageFolder','setBarVisible','toggleBar']
        script=r'''"use strict";
const assert = require('node:assert/strict');
let widgetSizes={}, widgetWorkspaceRules={}, workspaceNotes={}, widgetImageFolder='', barVisible=true;
const defaultWidgetSizes={notes:{width:320,height:235},kanban:{width:355,height:255}};
let saved=0; function save(){saved++;}
__FUNCS__
assert.equal(widgetAllowedOnWorkspace('notes', 2, 'DP-2'),true);
setWidgetWorkspaces('notes','DP-2',[2,3]);
assert.equal(widgetAllowedOnWorkspace('notes',2,'DP-2'),true);
assert.equal(widgetAllowedOnWorkspace('notes',1,'DP-2'),false);
assert.equal(widgetAllowedOnWorkspace('notes',1,'DP-1'),true);
assert.equal(workspaceNoteKey('DP-2',2),'DP-2:2');
setWorkspaceNote('DP-2',2,'This note is private to workspace 2');
assert.equal(workspaceNote('DP-2',2),'This note is private to workspace 2');
assert.equal(workspaceNote('DP-1',2),'');
setWidgetSize('notes','DP-2',480,320);
assert.deepEqual(widgetSize('notes','DP-2'),{width:480,height:320,w:480,h:320});
assert.equal(widgetSize('kanban','DP-2').width,355);
assert.equal(widgetSize('notes','DP-1').width,320);
setWidgetImageFolder('/home/user/Pictures'); assert.equal(widgetImageFolder,'/home/user/Pictures');
assert.equal(saved,3+1); // workspace rules, note, dimensions, image folder
setBarVisible(false); assert.equal(barVisible,false);
toggleBar(); assert.equal(barVisible,true);
assert.equal(saved,6);
console.log('Widget compat and bar persistence JS passed');
'''.replace('__FUNCS__','\n'.join(func(n) for n in names))
        result=subprocess.run(['node','-e',script],text=True,capture_output=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr+'\n'+result.stdout)

    def test_bar_buttons_recovery_works_when_hidden(self):
        qml=(ROOT/'modules/main/Bar.qml').read_text()
        recovery=(ROOT/'modules/main/BarRecoveryHandle.qml').read_text()
        shell=(ROOT/'shell.qml').read_text()
        zone=(ROOT/'components/BarZone.qml').read_text()
        page=(ROOT/'modules/settings/pages/SettingsBarPage.qml').read_text()
        self.assertIn('visible: SettingsStore.barVisible',qml)
        self.assertIn('visible: !SettingsStore.barVisible',recovery)
        self.assertIn('onClicked: SettingsStore.setBarVisible(true)',recovery)
        self.assertIn('exclusionMode: ExclusionMode.Ignore',recovery)
        self.assertIn('BarRecoveryHandle { required property var modelData; screen: modelData }',shell)
        self.assertIn('SettingsStore.toggleBar()',shell)
        self.assertIn('SettingsStore.setBarVisible(false)',shell)
        self.assertIn('SettingsStore.setBarVisible(true)',shell)
        self.assertIn('id: barTogglePart',zone)
        self.assertIn('heading: "Bar visibility"',page)
        self.assertIn('Show bar',page)
        self.assertIn('Hide bar',page)

    def test_shortcut_actions_can_register_in_existing_omarchy_registry(self):
        file=ROOT/'scripts/rustiq-desktop-integration.py'
        spec=importlib.util.spec_from_file_location('rusticq_shortcut_test',file)
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        for action in ['bar-toggle','bar-show','bar-hide','bar-hide-completely']:
            self.assertIn(action,mod.ACTIONS)
        self.assertEqual(mod.BAR_ACTIONS['barToggle'],['bar-toggle','bar-show','bar-hide','bar-hide-completely'])
        cmd = mod.write_shortcuts({'bar-toggle':'SUPER + ALT + B'},'-- user binds\n',{})
        self.assertIn('RusticQ Toggle desktop bar',cmd)
        self.assertIn('dispatch bar-toggle',cmd)
        self.assertNotIn('o.rebind(',cmd)
        cmd = mod.write_shortcuts({'bar-hide-completely':'SUPER + ALT + H'},'-- user binds\n',{})
        self.assertIn('dispatch bar-hide-completely',cmd)
        self.assertIn('RusticQ Show / hide bar completely',cmd)
        self.assertIn('{key: "barToggle", name: "Bar visibility"}',
                      (ROOT/'modules/settings/pages/SettingsShortcutsPage.qml').read_text())
        self.assertIn('if (action === "bar-hide-completely") { SettingsStore.toggleBarCompletely(); return; }',
                      (ROOT/'shell.qml').read_text())

if __name__=='__main__': unittest.main()
