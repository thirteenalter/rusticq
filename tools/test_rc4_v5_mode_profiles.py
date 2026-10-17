#!/usr/bin/env python3
"""Regression tests for v5 layout-isolated bar profiles and settings sizing.

Runs extracted QML JavaScript functions in Node to exercise the actual source.
No Quickshell/Hyprland installation required.
"""
import importlib.util
import json
import re
import subprocess
from pathlib import Path
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
store = (PROJECT / 'config/SettingsStore.qml').read_text()


def grab(name):
    match = re.search(r'(?m)^    function ' + re.escape(name) + r'\([^\n]*\) \{', store)
    assert match, f'QML function {name} missing'
    start = match.start() + 4
    depth = 0
    for i in range(match.end() - 1, len(store)):
        if store[i] == '{':
            depth += 1
        if store[i] == '}':
            depth -= 1
            if depth == 0:
                return store[start:i + 1]
    raise AssertionError('Unbalanced QML function ' + name)


functions = '\n'.join(grab(name) for name in [
    'modeIconVisible', 'setModeIconVisible', 'validateVisibilityProfiles',
    'resetModeVisibility', 'useMinimalModePreset', 'copyVisibilityFromMode',
    'placementFor', 'transferIconSpacing', 'setIconPlacement',
    'resetIconPlacements', 'validateIconPlacements', 'validateModePlacements'])
keys = re.search(r'readonly property var barVisibilityKeys: (\[[^;]+?\])\n    //', store, re.S)
assert keys, 'Visibility key registry not found'
simple = re.search(r'readonly property var simpleHiddenIcons: (\[[^;]+?\])\n    property var', store, re.S)
assert simple, 'Simple defaults not found'
placements = re.search(r'readonly property var defaultBarPlacements: \(\{(.*?)\}\)', store, re.S)
assert placements, 'Default placement registry not found'

js = '''const assert = require('node:assert/strict');
const barVisibilityKeys = __KEYS__;
const simpleHiddenIcons = __SIMPLE__;
const barIconKeys = ['rusticq','arch','launcher','menu','workspaces','weather','time','date','bluetooth','wifi','battery','audio','task','quickModes','quickControl','mic','down','up'];
const defaultBarPlacements = {__PLACEMENTS__};
const spacingModes = ['compact','clean-compact','separated','professional','simple'];
const spacingZones = ['left','center','right'];
let barMode = 'simple';
let barIconVisibilityProfiles = {};
let barIconPlacementsByMode = {};
let barSpacingOverrides = {simple: {right: {items: {wifi: {before: 8}}}}, professional: {right: {items: {wifi: {before: 5}}}}};
let saved = 0;
let barIconPlacements = {};
const root = {};
for (const key of barVisibilityKeys) root[key] = true;
root.showMicrophoneStatus = false;
root.showDownloadSpeed = false;
root.showUploadSpeed = false;
function save() { saved++; }
function barIconMoved() { }
__FUNCTIONS__
assert.equal(modeIconVisible('showWeather'), false, 'Simple defaults lean');
assert.equal(modeIconVisible('showLauncher'), true, 'Simple keeps launcher');
assert.equal(modeIconVisible('showWeather','professional'), true, 'Professional full defaults');
setModeIconVisible('showWeather', true);
assert.equal(modeIconVisible('showWeather'), true);
assert.equal(modeIconVisible('showWeather','professional'), true);
barMode = 'professional';
setModeIconVisible('showWeather', false);
assert.equal(modeIconVisible('showWeather','professional'), false);
assert.equal(modeIconVisible('showWeather','simple'), true);
assert.equal(modeIconVisible('showWeather','separated'), true);
useMinimalModePreset();
assert.equal(modeIconVisible('showWeather','professional'), false);
assert.equal(modeIconVisible('showLauncher','professional'), true);
assert.equal(modeIconVisible('showMenuBar','professional'), false);
assert.equal(modeIconVisible('showWeather','simple'), true);
barMode = 'compact';
copyVisibilityFromMode('simple');
assert.equal(modeIconVisible('showWeather'), true);
setModeIconVisible('showWeather', false);
assert.equal(modeIconVisible('showWeather','simple'), true, 'Copy must not alias source');
resetModeVisibility();
assert.equal(modeIconVisible('showWeather','compact'), true);
assert.equal(modeIconVisible('showWeather','professional'), false);
let validated = validateVisibilityProfiles({simple: {showWeather: true, arbitrary: true, showBattery: 'no'}, evil: {showTime: false}});
assert.deepEqual(validated, {simple: {showWeather: true}});
assert.equal(saved >= 5, true, 'writes persist');
barMode = 'simple';
assert.equal(placementFor('wifi'), 'right');
setIconPlacement('wifi', 'left');
assert.equal(placementFor('wifi'), 'left');
assert.equal(barSpacingOverrides.simple.left.items.wifi.before, 8, 'spacing follows icon in current mode');
assert.equal(barSpacingOverrides.professional.right.items.wifi.before, 5, 'other mode spacing unaffected');
barMode = 'professional';
assert.equal(placementFor('wifi'), 'right', 'other mode placement unaffected');
setIconPlacement('wifi', 'center');
assert.equal(placementFor('wifi'), 'center');
barMode = 'simple';
resetIconPlacements();
assert.equal(placementFor('wifi'), 'right');
assert.equal(barSpacingOverrides.simple.right.items.wifi.before, 8, 'reset spacing restores original zone');
barMode = 'professional';
assert.equal(placementFor('wifi'), 'center', 'reset affects only one mode');
assert.deepEqual(validateModePlacements({simple: {wifi:'left', evil:'center'},unknown:{wifi:'right'}}), {simple:{wifi:'left'}});
console.log('PASS: v5 live QML JS visibility, migration validators, presets, copy, mode isolation, placement and spacing');
'''.replace('__KEYS__', keys.group(1)).replace('__SIMPLE__', simple.group(1)).replace('__PLACEMENTS__', placements.group(1)).replace('__FUNCTIONS__', functions)
result = subprocess.run(['node', '-e', js], capture_output=True, text=True, timeout=10)
assert result.returncode == 0, result.stdout + '\n' + result.stderr
print(result.stdout.strip())

# Compositor helper must honor requested size, and scale down for other monitors.
spec = importlib.util.spec_from_file_location('floating', PROJECT / 'scripts/rustiq-settings-float.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
assert (module.DEFAULT_WIDTH, module.DEFAULT_HEIGHT) == (1100, 760)
class Result:
    returncode = 0
    stdout = json.dumps([{'id': 1, 'name': 'HDMI-A-1', 'width': 1920, 'height': 1080, 'scale': 1},
                         {'id': 2, 'name': 'DP-1', 'width': 1280, 'height': 720, 'scale': 1},
                         {'id': 3, 'name': 'DP-2', 'width': 2560, 'height': 1440, 'scale': 2}])
with patch.object(module.subprocess, 'run', return_value=Result()):
    assert module.target_size({'monitor': 1}) == (1100, 760)
    assert module.target_size({'monitor': 2}) == (1100, 632)
    assert module.target_size({'monitor': 'DP-2'}) == (1100, 632)
print('PASS: settings float target 1100 x 760 and per-monitor logical geometry')

# Ensure all three bar consumers bind to per-mode visibility; notifications stay global.
for path in ('components/BarZone.qml', 'components/ContextMenuBar.qml',
             'components/QuickModes.qml', 'modules/main/Bar.qml', 'modules/main/ContextMenu.qml'):
    assert 'modeIconVisible(' in (PROJECT / path).read_text(), path
assert 'SettingsStore.showNotifications' in (PROJECT/'modules/main/NotificationToasts.qml').read_text()
assert 'perBarMode:' in (PROJECT/'modules/settings/pages/SettingsModulesPage.qml').read_text()
assert 'barIconPlacementsByMode: barIconPlacementsByMode' in store
assert 'barIconVisibilityProfiles: barIconVisibilityProfiles' in store
print('PASS: bar/menu/quick-modes bindings and persistent profile serialization')
