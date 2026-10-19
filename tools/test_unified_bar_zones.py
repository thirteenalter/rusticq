#!/usr/bin/env python3
"""Source regression checks and QML-JavaScript placement migration simulation.
Not an in-session Quickshell/Hyprland UI test.
"""
from pathlib import Path
import subprocess
import json
import re

root=Path(__file__).resolve().parents[1]
store=(root/'config/SettingsStore.qml').read_text()
modules=(root/'modules/settings/pages/SettingsModulesPage.qml').read_text()
barpage=(root/'modules/settings/pages/SettingsBarPage.qml').read_text()
editor=(root/'modules/settings/pages/BarSpacingEditor.qml').read_text()
zone=(root/'components/BarZone.qml').read_text()
vertical=(root/'modules/main/VerticalBarContent.qml').read_text()

for key in ['showMicrophoneStatus','showDownloadSpeed','showUploadSpeed']:
    assert key in modules, f'{key} missing in Modules'
    assert key in store, f'{key} missing from persistence'
    assert key in modules, f'{key} is controlled from Modules' 
assert 'heading: "Extra status icons"' not in barpage
assert 'BarAlignmentEditor' in barpage
assert 'Icon spacing & drag ordering · Left / Center / Right' in barpage
assert '"center"' in editor and 'settingsGroup' not in editor
assert 'SettingsStore.placementFor(item.key) === side' in editor
assert 'onBarIconMoved(key, zone)' in editor
assert 'signal barIconMoved(string key, string zone)' in store
assert 'SettingsStore.spacingGroup(root.zone' in zone
assert 'Layout.topMargin: SettingsStore.spacingIcon(root.zone' in zone
assert 'Layout.bottomMargin: SettingsStore.spacingIcon(root.zone' in zone
assert 'zone: "center"' in vertical
assert 'for (const side of spacingZones)' in store

# Extract the actual JS functions from SettingsStore and execute in Node with
# stand-in QML properties. This tests migration for all modes, not just text.
def function_block(name):
    match=re.search(r'    function '+re.escape(name)+r'\([^\n]*\)\s*\{',store)
    assert match, f'function not found: {name}'
    depth=1; cursor=match.end()
    while depth and cursor<len(store):
        char=store[cursor]
        if char=='{': depth+=1
        if char=='}': depth-=1
        cursor+=1
    assert depth==0
    return store[match.start():cursor]

functions=['normalizeBarOrder','barOrder','validateBarIconOrder','placementFor','transferIconSpacing','setIconPlacement','resetIconPlacements','spacingGroup','spacingIcon','validSpacingItem','setGroupSpacing','setIconSpacing','iconsInZone','validateSpacingOverrides']
js='''
const assert = require('node:assert/strict');
const keys = ['arch','launcher','menu','workspaces','weather','time','date','bluetooth','wifi','battery','audio','notifications','task','quickModes','quickControl','mic','down','up'];
const defaults = Object.fromEntries(keys.map(k=>[k,['arch','launcher','menu','workspaces'].includes(k)?'left':'right']));
const ctx={
  barIconKeys:keys,defaultBarPlacements:defaults,
  barIconPlacements:{},barIconPlacementsByMode:{},barIconOrderByMode:{},barSpacingOverrides:{},
  spacingModes:['compact','clean-compact','separated','professional','simple'],
  spacingZones:['left','center','right'],barMode:'compact',saves:0,
  save(){this.saves++},barIconMoved(){}
};
'''
# bind QML methods with "with(ctx)" so plain property references match runtime.
for name in functions:
    js+=f'ctx.{name}=function(...params) {{ with(ctx) {{ return ({function_block(name)})(...params); }} }};\n'
js+='''
const expected = ['compact','clean-compact','separated','professional','simple'];
for (const [i,mode] of expected.entries()) {
  ctx.barMode=mode;
  ctx.setIconSpacing('right','wifi','before',i+3,true);
  ctx.setIconSpacing('right','wifi','after',i+4,true);
  ctx.setIconPlacement('wifi','center');
}
ctx.barMode='compact';
assert.equal(ctx.placementFor('wifi'),'center');
assert(ctx.iconsInZone('center').includes('wifi'));
assert(!ctx.iconsInZone('right').includes('wifi'));
for (const [i,mode] of expected.entries()) {
  ctx.barMode=mode;
  assert.equal(ctx.placementFor('wifi'),'center');
  assert.equal(ctx.spacingIcon('center','wifi','before'),i+3);
  assert.equal(ctx.spacingIcon('center','wifi','after'),i+4);
  assert.equal(ctx.spacingIcon('right','wifi','before'),0);
}
ctx.barMode='separated';
ctx.setGroupSpacing('center',12,true);
assert.equal(ctx.spacingGroup('center',5),12);
ctx.setIconPlacement('wifi','left');
assert.equal(ctx.spacingIcon('left','wifi','before'),5);
ctx.resetIconPlacements();
assert.equal(ctx.placementFor('wifi'),'right');
assert.equal(ctx.spacingIcon('right','wifi','before'),5);
assert(!ctx.iconsInZone('center').includes('wifi'));
ctx.barMode='compact';
assert.equal(ctx.placementFor('wifi'),'center','reset separated must not change compact');
assert.equal(ctx.spacingIcon('center','wifi','before'),3);
assert.equal(ctx.validateSpacingOverrides(ctx.barSpacingOverrides).separated.center.gap,12);
assert(ctx.saves>0);
console.log('Per-mode placement and spacing: five modes, 3 zones, isolated reset OK');
'''
# Assignment of methods on ctx uses JS function expressions with `with(ctx)`
# supported in non-strict Node commonjs.
result=subprocess.run(['node','-e',js],capture_output=True,text=True,timeout=10)
assert result.returncode==0, result.stderr
print(result.stdout.strip())
print('Unified zones source checks: passed')
