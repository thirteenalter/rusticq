#!/usr/bin/env python3
"""Regression: real editor QML JS handles insertion slots AND card swap targets.

Runs QML functions from the file in Node with deterministic mocked QQuickItem
geometry. This cannot replace actual DragHandler/Flow runtime testing in Wayland.
"""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
EDITOR = (ROOT / 'modules/settings/pages/BarAlignmentEditor.qml').read_text()
STORE = (ROOT / 'config/SettingsStore.qml').read_text()


def fn(source, name):
    match = re.search(r'(?m)^    function ' + re.escape(name) + r'\([^\n]*\) \{', source)
    if not match:
        raise AssertionError('QML function missing: ' + name)
    depth = 0
    for i in range(match.end() - 1, len(source)):
        if source[i] == '{':
            depth += 1
        elif source[i] == '}':
            depth -= 1
            if depth == 0:
                return source[match.start() + 4:i + 1]
    raise AssertionError('Unbalanced QML function: ' + name)


class DragInsertTests(unittest.TestCase):
    def test_preview_and_drop_slot_resolution_from_qml_functions(self):
        functions = '\n'.join(fn(EDITOR, n) for n in ('findSlot', 'updateDrop', 'finishDrop'))
        js = r'''
const assert = require('node:assert/strict');
const SettingsStore = {
  barIconKeys:['a','b','c','d','e','f'],
  moves:[], swaps:[],
  moveBarIcon(k,z,before) { this.moves.push([k,z,before]); return true; },
  swapBarIcons(a,b) { this.swaps.push([a,b]); return true; }
};
const root={};
let draggingKey='',previewKind='',previewZone='',previewBeforeKey='',previewSwapKey='',previewX=0,previewY=0;
function tile(key,x,y) {
  return {iconKey:key,width:133,height:70,mapToItem(){return {x,y}}};
}
function panel(zone,x,y,w,h,tiles) {
  return {
    modelData:{zone},width:w,height:h,
    mapToItem(){return {x,y}},
    tileCount(){return tiles.length},tileAt(i){return tiles[i]},
    dropOrigin(){return {x:x+12,y:y+31}}
  };
}
const panels=[
  panel('left',0,0,500,130,[tile('a',12,40),tile('b',152,40),tile('c',292,40)]),
  panel('center',0,140,500,130,[tile('d',12,180)]),
  panel('right',0,280,500,230,[tile('e',12,320),tile('f',152,320),tile('unused',12,397)])
];
const zoneRepeater={count:panels.length,itemAt(i){return panels[i]}};
__FUNCTIONS__
// Real insertion boundary: a dragged item points to the gap between b and c.
let slot=findSlot('a',287,75);
assert.equal(slot.zone,'left');
assert.equal(slot.kind,'insert');
assert.equal(slot.beforeKey,'c');
assert.equal(slot.x,288);
assert.equal(slot.y,43);
// On the central body of b, the preview is a SWAP target (no insertion caret).
slot=findSlot('a',220,75);
assert.equal(slot.zone,'left');
assert.equal(slot.kind,'swap');
assert.equal(slot.targetKey,'b');
// Edge of b is still an INSERT, not a swap.
slot=findSlot('a',157,75);
assert.equal(slot.kind,'insert');
assert.equal(slot.beforeKey,'b');
// Dropping after c appends in left.
slot=findSlot('a',431,75);
assert.equal(slot.beforeKey,'');
// Crossing into another zone recognizes its earliest boundary.
slot=findSlot('a',6,214);
assert.equal(slot.zone,'center');
assert.equal(slot.beforeKey,'d');
// Wrapping produces a marker near the corresponding visual row.
slot=findSlot('a',8,430);
assert.equal(slot.zone,'right');
assert.equal(slot.beforeKey,'unused');
// A zone with no other tile still offers a visible insertion slot.
panels[1]=panel('center',0,140,500,130,[tile('a',12,180)]);
slot=findSlot('a',30,200);
assert.equal(slot.zone,'center');
assert.equal(slot.beforeKey,'');
// Restore the mock destination tile for the following cross-zone swap.
panels[1]=panel('center',0,140,500,130,[tile('d',12,180)]);
// No valid drop outside any panel: icon order is not modified.
assert.equal(findSlot('a',900,800),null);
// A cross-zone center drop swaps with d.
slot=findSlot('a',78,214);
assert.equal(slot.kind,'swap');
assert.equal(slot.targetKey,'d');
draggingKey='a';updateDrop('a',287,75);
assert.equal(previewZone,'left');
assert.equal(previewKind,'insert');
assert.equal(previewBeforeKey,'c');
assert.equal(finishDrop('a',287,75),true);
assert.deepEqual(SettingsStore.moves,[['a','left','c']]);
assert.equal(previewZone,'');
assert.equal(previewKind,'');
assert.equal(previewSwapKey,'');
assert.equal(draggingKey,'');
// Second action is true slot-for-slot replacement (not insertion).
draggingKey='a';updateDrop('a',220,75);
assert.equal(previewKind,'swap');
assert.equal(previewSwapKey,'b');
assert.equal(finishDrop('a',220,75),true);
assert.deepEqual(SettingsStore.swaps,[['a','b']]);
assert.equal(SettingsStore.moves.length,1);
// Cross-zone SWAP chooses the target icon's zone without a shift.
draggingKey='a';updateDrop('a',78,214);
assert.equal(finishDrop('a',78,214),true);
assert.deepEqual(SettingsStore.swaps,[['a','b'],['a','d']]);
// An out-of-panel release is a no-op.
draggingKey='a';
assert.equal(finishDrop('a',900,800),false);
assert.equal(SettingsStore.moves.length,1);
assert.equal(SettingsStore.swaps.length,2);
console.log('PASS: exact QML geometry insert + swap, center/edge, cross-zone, wrap, empty, release');
'''.replace('__FUNCTIONS__', functions)
        proc = subprocess.run(['node', '-e', js], capture_output=True, text=True, timeout=10)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_persisted_insertion_shifts_icons_not_swaps(self):
        functions = '\n'.join(fn(STORE, n) for n in (
            'validateBarIconOrder','barOrder','placementFor','transferIconSpacing',
            'moveBarIcon','iconsInZone'))
        js = r'''
const assert=require('node:assert/strict');
const barIconKeys=['rusticq','arch','launcher','menu','workspaces','weather','wifi','battery'];
const defaultBarPlacements={rusticq:'left',arch:'left',launcher:'left',menu:'left',workspaces:'left',weather:'right',wifi:'right',battery:'right'};
const spacingZones=['left','center','right'];
let barMode='simple',barIconOrderByMode={},barIconPlacementsByMode={},barSpacingOverrides={};
let persisted=0;
function save(){ persisted++ };
function barIconMoved() {}
__FUNCTIONS__
assert.deepEqual(iconsInZone('left'),['rusticq','arch','launcher','menu','workspaces']);
assert.equal(moveBarIcon('rusticq','left','menu'),true);
assert.deepEqual(iconsInZone('left'),['arch','launcher','rusticq','menu','workspaces']);
// This is an insert: arch and launcher shift left; they do NOT swap with rusticq.
assert.equal(moveBarIcon('wifi','left','launcher'),true);
assert.deepEqual(iconsInZone('left'),['arch','wifi','launcher','rusticq','menu','workspaces']);
assert.deepEqual(iconsInZone('right'),['weather','battery']);
barMode='professional';
assert.deepEqual(iconsInZone('left'),['rusticq','arch','launcher','menu','workspaces']);
barMode='simple';
assert.equal(moveBarIcon('launcher','left',''),true);
assert.equal(iconsInZone('left').at(-1),'launcher');
assert.ok(persisted>=3);
console.log('PASS: persisted true insertion, cross-zone, and isolated layout modes');
'''.replace('__FUNCTIONS__',functions)
        proc = subprocess.run(['node','-e',js],capture_output=True,text=True,timeout=10)
        self.assertEqual(proc.returncode,0,proc.stdout+proc.stderr)

    def test_combined_release_mutates_actual_store_for_both_modes(self):
        # Exercise the REAL extracted editor+store JS together, not two stub mocks.
        editor_js = '\n'.join(fn(EDITOR, n) for n in ('findSlot','updateDrop','finishDrop'))
        store_js = '\n'.join(fn(STORE, n) for n in (
            'validateBarIconOrder', 'barOrder', 'placementFor',
            'transferIconSpacing', 'moveBarIcon', 'swapBarIcons', 'iconsInZone'))
        program = r'''
const assert=require('node:assert/strict');
const barIconKeys=['rusticq','arch','launcher','menu','workspaces','weather','wifi','battery'];
const defaultBarPlacements={rusticq:'left',arch:'left',launcher:'left',menu:'left',workspaces:'left',weather:'right',wifi:'right',battery:'right'};
const spacingZones=['left','center','right'];
let barMode='simple',barIconOrderByMode={},barIconPlacementsByMode={},barSpacingOverrides={};
let saved=0;
function save(){saved++};function barIconMoved(){}
__STORE_FUNCTIONS__
const SettingsStore={barIconKeys,moveBarIcon,swapBarIcons};
const root={};
let draggingKey='',previewKind='',previewZone='',previewBeforeKey='',previewSwapKey='',previewX=0,previewY=0;
function tile(key,x,y){return {iconKey:key,width:133,height:70,mapToItem(){return {x,y}}};}
function panel(zone,x,y,w,h,tiles){return {modelData:{zone},width:w,height:h,
  mapToItem(){return {x,y}},tileCount(){return tiles.length},tileAt(i){return tiles[i]},
  dropOrigin(){return {x:x+11,y:y+31}}};}
const panels=[
  panel('left',0,0,850,135,[tile('rusticq',12,40),tile('arch',152,40),tile('launcher',292,40),tile('menu',432,40),tile('workspaces',572,40)]),
  panel('center',0,140,850,130,[]),
  panel('right',0,280,850,140,[tile('weather',12,320),tile('wifi',152,320),tile('battery',292,320)])
];
const zoneRepeater={count:panels.length,itemAt(i){return panels[i]}};
__EDITOR_FUNCTIONS__
// Drop RusticQ at the *center* of Launcher: exact two-way swap.
draggingKey='rusticq';assert.equal(finishDrop('rusticq',358,75),true);
assert.deepEqual(iconsInZone('left'),['launcher','arch','rusticq','menu','workspaces']);
// Drop Wi-Fi at the center of Arch: cross-zone exchange.
draggingKey='wifi';assert.equal(finishDrop('wifi',218,75),true);
assert.deepEqual(iconsInZone('left'),['launcher','wifi','rusticq','menu','workspaces']);
assert.deepEqual(iconsInZone('right'),['weather','arch','battery']);
// QML Flow reflows after swap; update mocked geometry to match real tiles.
panels[0]=panel('left',0,0,850,135,[tile('launcher',12,40),tile('wifi',152,40),tile('rusticq',292,40),tile('menu',432,40),tile('workspaces',572,40)]);
panels[2]=panel('right',0,280,850,140,[tile('weather',12,320),tile('arch',152,320),tile('battery',292,320)]);
// Drop the RusticQ icon *between* Launcher and Wi-Fi: true insert/shift.
draggingKey='rusticq';assert.equal(finishDrop('rusticq',147,75),true);
assert.deepEqual(iconsInZone('left'),['launcher','rusticq','wifi','menu','workspaces']);
// Persisted changes affect Simple only; Professional remains untouched.
barMode='professional';
assert.deepEqual(iconsInZone('left'),['rusticq','arch','launcher','menu','workspaces']);
assert.deepEqual(iconsInZone('right'),['weather','wifi','battery']);
assert.equal(saved,3);
console.log('PASS: real QML drag release -> real SettingsStore swap + insert, cross-zone and per-mode');
'''.replace('__STORE_FUNCTIONS__',store_js).replace('__EDITOR_FUNCTIONS__',editor_js)
        proc = subprocess.run(['node', '-e', program], capture_output=True, text=True, timeout=10)
        self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)

    def test_live_marker_rendered_outside_flow(self):
        self.assertIn('id: insertPlaceholder', EDITOR)
        self.assertIn('visible: root.draggingKey.length > 0', EDITOR)
        self.assertIn('onTranslationChanged:', EDITOR)
        self.assertIn('mapFromItem(root, root.previewX, root.previewY)', EDITOR)
        self.assertIn('root.finishDrop(tile.iconKey', EDITOR)
        self.assertIn('SettingsStore.swapBarIcons(key, swapTarget)', EDITOR)
        self.assertIn('return SettingsStore.moveBarIcon(key, zone, before);', EDITOR)
        self.assertIn('root.previewKind === "insert"', EDITOR)
        self.assertIn('root.previewKind === "swap"', EDITOR)
        self.assertIn('↔ Swap', EDITOR)
        self.assertIn('SettingsStore.iconsInZone(zone)', (ROOT / 'components/BarZone.qml').read_text())


if __name__=='__main__':
    unittest.main()
