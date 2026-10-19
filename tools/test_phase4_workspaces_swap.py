#!/usr/bin/env python3
"""Offline, source-derived QML JavaScript regression for Phase 4 fixes."""
from pathlib import Path
import re
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]
STORE=(ROOT/'config/SettingsStore.qml').read_text()

def method(name):
    match=re.search(r'(?m)^    function '+re.escape(name)+r'\([^\n]*\) \{',STORE)
    assert match,name
    depth=0
    for i in range(match.end()-1,len(STORE)):
        if STORE[i]=='{':depth+=1
        elif STORE[i]=='}':
            depth-=1
            if depth==0:return STORE[match.start()+4:i+1]
    raise AssertionError('Unbalanced '+name)

class WidgetSwapTests(unittest.TestCase):
    def test_real_qml_swap_and_workspace_storage(self):
        methods=['validateBarIconOrder','normalizeBarOrder','barOrder','placementFor','transferIconSpacing','swapBarIcons',
                 'iconsInZone','widgetAllowedOnWorkspace','setWidgetWorkspace',
                 'workspaceNoteKey','workspaceNote','setWorkspaceNote','widgetKey',
                 'widgetPosition','setWidgetPosition','widgetSize','setWidgetSize']
        fn='\n'.join(method(x) for x in methods)
        program=r'''
const assert = require('node:assert/strict');
const barIconKeys=['rusticq','arch','launcher','menu','workspaces','weather','time','date','bluetooth','wifi','battery','audio','notifications','task','quickModes','quickControl','mic','down','up'];
const defaultBarPlacements={};
for(const key of barIconKeys) defaultBarPlacements[key]=['rusticq','arch','launcher','menu','workspaces'].includes(key)?'left':'right';
const spacingModes=['compact','clean-compact','separated','professional','simple'];
const spacingZones=['left','center','right'];
let barMode='simple',barIconOrderByMode={},barIconPlacementsByMode={},barSpacingOverrides={};
let widgetWorkspaceScopes={notes:[1],kanban:[1],randomImage:[1]},workspaceNotes={},widgetPositions={},widgetSizes={};
let saves=0, moved=[];
function save(){saves++}; function barIconMoved(k,z){moved.push([k,z]);}
__METHODS__
assert.equal(swapBarIcons('rusticq','launcher'),true);
assert.deepEqual(iconsInZone('left'),['launcher','arch','rusticq','menu','workspaces']);
assert.equal(swapBarIcons('rusticq','wifi'),true);
assert.equal(placementFor('rusticq'),'right');
assert.equal(placementFor('wifi'),'left');
assert.equal(iconsInZone('left')[2],'wifi');
assert.equal(iconsInZone('right')[barIconKeys.indexOf('rusticq')>=0 ? 4:0] !== undefined,true);
barMode='professional';
assert.equal(placementFor('rusticq'),'left');
assert.equal(placementFor('wifi'),'right');
barMode='simple';
assert.equal(widgetAllowedOnWorkspace('notes',1),true);
assert.equal(widgetAllowedOnWorkspace('notes',2),false);
setWidgetWorkspace('notes',2,true);
assert.deepEqual(widgetWorkspaceScopes.notes,[1,2]);
setWidgetWorkspace('notes',1,false);
assert.deepEqual(widgetWorkspaceScopes.notes,[2]);
assert.equal(widgetAllowedOnWorkspace('notes',1),false);
assert.equal(widgetAllowedOnWorkspace('kanban',1),true);
setWorkspaceNote('eDP-1',2,'hello\nfrom workspace two');
setWorkspaceNote('eDP-1',1,'workspace one');
assert.equal(workspaceNote('eDP-1',2),'hello\nfrom workspace two');
assert.equal(workspaceNote('eDP-1',1),'workspace one');
assert.equal(workspaceNote('HDMI-A-1',1),'');
setWidgetPosition('notes','eDP-1',.3,.4,2);
setWidgetPosition('notes','eDP-1',.8,.7,1);
assert.deepEqual(widgetPosition('notes','eDP-1',2),{x:.3,y:.4});
assert.deepEqual(widgetPosition('notes','eDP-1',1),{x:.8,y:.7});
setWidgetSize('notes','eDP-1',2,522,333);
assert.deepEqual(widgetSize('notes','eDP-1',2),{width:522,height:333});
assert.equal(widgetSize('notes','eDP-1',1),null);
assert.equal(saves>=8,true);
console.log('PASS: swap, cross-zone, per-layout isolation, workspace scopes, independent scratchpads and geometry');
'''.replace('__METHODS__',fn)
        proc=subprocess.run(['node','-e',program],capture_output=True,text=True,timeout=10)
        self.assertEqual(proc.returncode,0,proc.stdout+proc.stderr)
    def test_widget_input_and_visibility_are_wired(self):
        win=(ROOT/'modules/main/DesktopWidgetWindow.qml').read_text()
        page=(ROOT/'modules/settings/pages/SettingsWidgetsPage.qml').read_text()
        editor=(ROOT/'modules/settings/pages/BarAlignmentEditor.qml').read_text()
        note=(ROOT/'modules/main/DesktopScratchpadCard.qml').read_text()
        self.assertIn('focusable: interactiveWidget',win)
        self.assertIn('Hyprland.monitorFor(screen)',win)
        self.assertIn('workspaceAllowed &&',win)
        self.assertIn('width: 36',win)
        self.assertIn('SettingsStore.setWidgetSize',win)
        self.assertIn('SettingsStore.setWidgetWorkspace',page)
        self.assertIn('TextEdit {',note)
        self.assertIn('setWorkspaceNote',note)
        self.assertIn('return SettingsStore.moveBarIcon(key, zone, before);',editor)
        self.assertIn('id: insertPlaceholder', editor)
        self.assertIn('root.updateDrop(tile.iconKey', editor)
        self.assertIn('root.finishDrop(tile.iconKey',editor)
        self.assertNotIn('id: itemDrop',editor)

if __name__=='__main__': unittest.main()
