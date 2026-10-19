#!/usr/bin/env python3
"""Regression coverage for Beta1 Phase4 widgets and per-mode bar reordering."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
STORE = (ROOT/'config/SettingsStore.qml').read_text()


def method(name):
    import re
    match = re.search(r'(?m)^    function ' + re.escape(name) + r'\([^\n]*\) \{', STORE)
    if not match:
        raise AssertionError('QML JS function not found: ' + name)
    pos = match.start()+4
    count=0
    for j in range(match.end()-1,len(STORE)):
        if STORE[j]=='{': count+=1
        elif STORE[j]=='}':
            count-=1
            if count==0: return STORE[pos:j+1]
    raise AssertionError('Unbalanced function '+name)

MODULE = ROOT/'scripts/rusticq-widget-images.py'
spec = importlib.util.spec_from_file_location('random_images',MODULE)
IMG = importlib.util.module_from_spec(spec)
spec.loader.exec_module(IMG)


class WidgetTests(unittest.TestCase):
    def test_only_local_photo_with_valid_uri(self):
        with tempfile.TemporaryDirectory(dir=Path.home()) as folder:
            path=Path(folder)
            (path/'good.jpg').write_bytes(b'\xff\xd8mock')
            (path/'second.png').write_bytes(b'mock')
            (path/'avoid.txt').write_bytes(b'mock')
            with tempfile.TemporaryDirectory() as outside:
                (Path(outside)/'private.png').write_bytes(b'mock')
                (path/'evil.png').symlink_to(Path(outside)/'private.png')
                image=IMG.choose(folder)
                self.assertTrue(image['ok'])
                self.assertTrue(image['uri'].startswith('file://'))
                self.assertEqual(image['count'],2)
                self.assertNotEqual(IMG.choose(folder, image['name'])['name'],image['name'])

    def test_cannot_scan_folder_outside_home(self):
        with tempfile.TemporaryDirectory() as outside:
            with self.assertRaisesRegex(ValueError,'inside your home'):
                IMG.choose(outside)

    def test_cannot_escape_via_symlink(self):
        with tempfile.TemporaryDirectory(dir=Path.home()) as folder, tempfile.TemporaryDirectory() as outside:
            (Path(folder)/'alias').symlink_to(outside,target_is_directory=True)
            with self.assertRaisesRegex(ValueError,'inside your home'):
                IMG.choose(str(Path(folder)/'alias'))

    def test_empty_folder_is_graceful(self):
        with tempfile.TemporaryDirectory(dir=Path.home()) as folder:
            response=IMG.choose(folder)
            self.assertFalse(response['ok'])
            self.assertEqual(response['count'],0)

    def test_proper_widget_and_store_integration(self):
        for name in ['DesktopNotesCard.qml','DesktopRandomImageCard.qml','DesktopWidgets.qml','DesktopWidgetWindow.qml']:
            self.assertTrue((ROOT/'modules/main'/name).is_file())
        main=(ROOT/'modules/main/DesktopWidgets.qml').read_text()
        for key in ('notes','kanban','randomImage'):
            self.assertIn('kind: "'+key+'"',main)
        page=(ROOT/'modules/settings/pages/SettingsWidgetsPage.qml').read_text()
        for key in ('desktopNotes','desktopKanban','desktopRandomImage','widgetImageFolder','widgetImageRotateSeconds'):
            self.assertIn(key,page)
            self.assertIn(key,STORE)
        notes=(ROOT/'modules/main/DesktopNotesCard.qml').read_text()
        self.assertIn('rusticq-notes.py',notes)
        self.assertIn('Store.notesChanged()',notes)
        self.assertIn('onNotesChanged()', (ROOT/'modules/settings/pages/SettingsNotesPage.qml').read_text())
        self.assertIn('barIconOrderByMode: barIconOrderByMode',STORE)

    def test_node_exec_actual_qml_bar_order_functions(self):
        names=['validateBarIconOrder','normalizeBarOrder','validateBarIconOrders','barOrder','placementFor',
               'transferIconSpacing','moveBarIcon','iconsInZone','resetIconPlacements']
        js='\n'.join(method(n) for n in names)
        code=r'''
const assert=require('node:assert/strict');
const barIconKeys=['rusticq','arch','launcher','menu','workspaces','weather','time','date','bluetooth','wifi','battery','audio','notifications','task','quickModes','quickControl','mic','down','up'];
const defaultBarPlacements={};
for(const k of barIconKeys) defaultBarPlacements[k]=['rusticq','arch','launcher','menu','workspaces'].includes(k)?'left':'right';
const spacingModes=['compact','clean-compact','separated','professional','simple'];
const spacingZones=['left','center','right'];
let barMode='simple',barIconOrderByMode={},barIconPlacementsByMode={},barSpacingOverrides={};
let written=0; function save(){written++}; function barIconMoved(){}
__FUNCTIONS__
assert.deepEqual(iconsInZone('left'),barIconKeys.slice(0,5));
assert.equal(validateBarIconOrder(barIconKeys.concat('extra')),false);
assert.equal(validateBarIconOrder(barIconKeys.slice().reverse()),true);
assert.deepEqual(validateBarIconOrders({simple:barIconKeys.slice().reverse(),hacker:['x']}),{simple:barIconKeys.slice().reverse()});
moveBarIcon('workspaces','left','rusticq');
assert.deepEqual(iconsInZone('left'),['workspaces','rusticq','arch','launcher','menu']);
moveBarIcon('rusticq','left','');
assert.deepEqual(iconsInZone('left'),['workspaces','arch','launcher','menu','rusticq']);
moveBarIcon('wifi','left','workspaces');
assert.equal(iconsInZone('left')[0],'wifi');
assert.equal(iconsInZone('right').includes('wifi'),false);
barMode='professional';
assert.equal(iconsInZone('right').includes('wifi'),true);
assert.equal(iconsInZone('left')[0],'rusticq');
barMode='simple';
resetIconPlacements();
assert.equal(iconsInZone('right').includes('wifi'),true);
assert.equal(iconsInZone('left')[0],'rusticq');
assert.equal(written>=4,true);
console.log('pass: drag/reorder, cross zone, per-mode isolation, reset');
'''.replace('__FUNCTIONS__',js)
        proc=subprocess.run(['node','-e',code],capture_output=True,text=True,timeout=10)
        self.assertEqual(proc.returncode,0,proc.stdout+proc.stderr)

    def test_bar_renderer_consumes_live_order(self):
        qml=(ROOT/'components/BarZone.qml').read_text()
        self.assertIn('SettingsStore.iconsInZone(zone)',qml)
        editor=(ROOT/'modules/settings/pages/BarAlignmentEditor.qml').read_text()
        self.assertIn('root.finishDrop(tile.iconKey',editor)
        self.assertIn('return SettingsStore.moveBarIcon(key, zone, before);',editor)
        self.assertIn('id: insertPlaceholder', editor)
        self.assertIn('root.updateDrop(tile.iconKey', editor)
        self.assertIn('SettingsStore.moveBarIcon(',editor)

if __name__=='__main__':
    unittest.main()
