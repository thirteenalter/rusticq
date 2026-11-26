#!/usr/bin/env python3
"""RAGE real QML controls, palette, resource lifetime, validation and persistence.

Offscreen, isolated user-settings.json; no compositor rules or real lock/PAM.
Use --native-smoke for the separately authorized Wayland/session-rule check.
"""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from test_clock_ui import run_qml

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "config"
import "components"
import "modules/settings/pages"
ShellRoot {
    Process { id: external; command: ["python3", Quickshell.shellPath("external.py")] }
    Window {
        id: window
        visible: true; width: 800; height: 900
        color: Theme.background
        Flickable {
            id: scroll
            width: 790; height: 890; clip: true
            contentHeight: settings.implicitHeight
            GlassSettings { id: settings; width: 770 }
        }
        GlassSurface { id: first; x: 780; width: 8; height: 30; baseRadius: 17 }
        GlassSurface { id: second; x: 790; width: 8; height: 30; baseRadius: 17 }
        TestCase {
            name: "RageUI"
            when: true
            function control(name) { const c = findChild(settings, name); verify(c !== null, name); return c; }
            function show(c) {
                scroll.contentY = Math.max(0, Math.min(scroll.contentHeight-scroll.height,
                    c.mapToItem(settings, 0, 0).y-100));
                wait(30);
            }
            function click(name) { const c=control(name); show(c); mouseClick(c); }
            function effects() { return findChild(first, "glassSurfaceEffects"); }
            function init() {
                SettingsStore.applyGlassSettings(SettingsStore.glassDefaults);
                SettingsStore.animationsEnabled = false;
                SettingsStore.lowMemoryShellMode = false;
                SettingsStore.colorSource = "gruvbox";
                Store.glassBlurActive = false;
                scroll.contentY = 0;
                wait(25);
            }
            function cleanup() { console.log("RAGE TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); }
            function cleanupTestCase() { console.log("RAGE RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
            function test_default_disabled_and_exact_restoration() {
                compare(SettingsStore.glassmorphismEnabled, false);
                compare(control("glassCustomizationControls").enabled, false);
                compare(control("glassOpacitySlider").enabled, false);
                compare(first.color, Theme.background); compare(first.radius, 17);
                const border=first.border.color, width=first.border.width;
                compare(effects().item, null);
                click("glassMasterToggle");
                compare(SettingsStore.glassmorphismEnabled, true);
                compare(control("glassCustomizationControls").enabled, true);
                verify(first.color.a < 1); compare(first.radius, 20);
                tryVerify(() => effects().item !== null);
                compare(control("glassPreviewText").opacity, 1);
                click("glassMasterToggle");
                compare(first.color, Theme.background); compare(first.radius, 17);
                compare(first.border.color, border); compare(first.border.width, width);
                tryCompare(effects(), "item", null);
                compare(SettingsStore.glassReflectionEnabled, true);
            }
            function test_keyboard_master_and_presets() {
                const toggle=control("glassMasterToggle");
                window.requestActivate(); toggle.forceActiveFocus();
                tryCompare(toggle, "activeFocus", true);
                keyClick(Qt.Key_Space);
                compare(SettingsStore.glassmorphismEnabled, true);
                for (const [style, opacity, tint, radius] of [["crystal",.24,.05,20],["tinted",.50,.30,20],["frosted",.44,.10,20]]) {
                    click("glassPreset_"+style);
                    compare(SettingsStore.glassStyle, style);
                    compare(SettingsStore.glassOpacity, opacity);
                    compare(SettingsStore.glassTintStrength, tint);
                    compare(first.radius, radius);
                }
                verify(!SettingsStore.setGlassPreset("__proto__"));
                SettingsStore.setGlassValue("glassOpacity", .73, false);
                compare(SettingsStore.glassStyle, "frosted"); compare(SettingsStore.glassOpacity, .73);
            }
            function test_native_provider_controls_without_glass() {
                const source=SettingsStore.colorSource;
                click("rageMode_exclusive");
                compare(Theme.paletteProvider,"rage");
                compare(SettingsStore.glassmorphismEnabled,false);
                click("ragePalette_pearl");
                compare(Theme.background,"#f2f2f5");
                compare(SettingsStore.colorSource,source);
                click("glassMasterToggle");
                click("glassPreset_crystal");
                compare(SettingsStore.ragePalette,"pearl");
                click("glassMasterToggle");
                compare(Theme.paletteProvider,"rage");
                click("rageMode_adaptive");
                compare(Theme.paletteProvider,"gruvbox");
                compare(SettingsStore.colorSource,source);
            }
            function test_slider_preview_commit_and_keyboard() {
                click("glassMasterToggle");
                const slider=control("glassOpacitySlider"); show(slider);
                const snapshot=SettingsStore.settingsSnapshot;
                mousePress(slider, slider.width*.60, slider.height/2);
                mouseMove(slider, slider.width*.68, slider.height/2, 30);
                verify(SettingsStore.glassOpacity !== .44);
                compare(SettingsStore.settingsSnapshot, snapshot);
                mouseRelease(slider, slider.width*.68, slider.height/2);
                verify(SettingsStore.settingsSnapshot !== snapshot);
                compare(JSON.parse(SettingsStore.settingsSnapshot).glassOpacity, SettingsStore.glassOpacity);
                window.requestActivate(); slider.forceActiveFocus();
                const before=SettingsStore.glassOpacity;
                keyClick(Qt.Key_Right);
                fuzzyCompare(SettingsStore.glassOpacity, before+.01, .0001);
                compare(first.color, second.color); compare(first.radius, second.radius);
                compare(Theme.glassColor("control", Theme.accent), Theme.accent);
            }
            function test_fallback_performance_low_memory_release_resources() {
                SettingsStore.glassmorphismEnabled = true;
                SettingsStore.glassOpacity = .40;
                verify(first.color.a >= .85);
                Store.glassBlurActive = true;
                fuzzyCompare(first.color.a, .40, .005);
                tryVerify(() => effects().item !== null);
                SettingsStore.glassPerformanceMode = true;
                tryCompare(effects(), "item", null);
                verify(first.color.a >= .85);
                compare(SettingsStore.glassOpacity, .40);
                SettingsStore.glassPerformanceMode = false;
                tryVerify(() => effects().item !== null);
                SettingsStore.lowMemoryShellMode = true;
                tryCompare(effects(), "item", null);
                compare(SettingsStore.glassReflectionEnabled, true);
                compare(SettingsStore.glassShadowEnabled, true);
                compare(control("glassBlurRadiusSlider").visible, false);
                compare(Theme.glassAuthentication.a, 1);
            }
            function test_palette_sources_and_semantic_colors() {
                for (const glass of [false,true]) {
                    SettingsStore.glassmorphismEnabled = glass;
                    compare(Theme.background, "#282828");
                    Theme.parseAether('background = "#182028"\\nforeground = "#f2e4ce"\\naccent = "#75b8bc"\\ncolor1 = "#ff6677"');
                    SettingsStore.colorSource = "aether";
                    compare(Theme.background, "#182028"); compare(Theme.foreground.a, 1);
                    compare(Theme.accent, "#75b8bc"); compare(Theme.error, "#ff6677");
                    compare(Theme.glassColor("control",Theme.error), Theme.error);
                    compare(first.color, second.color);
                    Theme.aetherPalette = ({});
                    compare(Theme.background, "#282828");
                    SettingsStore.colorSource = "gruvbox";
                }
            }
            function test_type_enum_and_range_validation() {
                const defaults=JSON.stringify(SettingsStore.glassDefaults);
                SettingsStore.applyGlassSettings({glassmorphismEnabled:"true",glassOpacity:null,
                    glassStyle:"other",glassBlurEnabled:1,glassCornerRadius:2.5,
                    glassBlurRadius:100,glassTintStrength:-1,glassBorderOpacity:[],glassShadowIntensity:".2"});
                for (const key of Object.keys(SettingsStore.glassDefaults)) compare(SettingsStore[key], SettingsStore.glassDefaults[key]);
                for (const value of [NaN,Infinity,null,".5",{}]) verify(!SettingsStore.setGlassValue("glassOpacity",value,false));
                verify(!SettingsStore.setGlassValue("showWifi",false));
                verify(!SettingsStore.setGlassValue("glassmorphismEnabled",1));
                verify(!SettingsStore.setGlassValue("__proto__",{}));
                SettingsStore.setGlassValue("glassOpacity",-1,false); compare(SettingsStore.glassOpacity,.15);
                SettingsStore.setGlassValue("glassCornerRadius",99,false); compare(SettingsStore.glassCornerRadius,32);
                compare(JSON.stringify(SettingsStore.glassDefaults),defaults);
            }
            function test_reset_restores_standard_without_other_preferences() {
                SettingsStore.glassmorphismEnabled=true;
                SettingsStore.setGlassPreset("crystal");
                const source=SettingsStore.colorSource, size=SettingsStore.barIconSize;
                click("glassResetButton");
                compare(SettingsStore.glassmorphismEnabled,false);
                compare(SettingsStore.glassStyle,"frosted"); compare(SettingsStore.glassOpacity,.44);
                compare(SettingsStore.colorSource,source); compare(SettingsStore.barIconSize,size);
                compare(first.color,Theme.background);
            }
            function test_z_external_edit_no_shell_reload_then_persist() {
                SettingsStore.save(); wait(100);
                external.running=true; tryCompare(external,"running",false);
                tryCompare(SettingsStore,"glassmorphismEnabled",true);
                compare(SettingsStore.glassOpacity,.71);
                compare(SettingsStore.barBackgroundEnabled,false);
                compare(SettingsStore.barSegmentRadius,16);
                compare(ShellReload.pending,false);
                compare(first.color,second.color);
                SettingsStore.setGlassPreset("tinted");
                SettingsStore.setGlassValue("glassOpacity",.74);
                SettingsStore.setGlassValue("glassCornerRadius",25);
                wait(150);
            }
        }
    }
}
'''


def fixture(folder):
    root = Path(folder)
    for name in ('config', 'components', 'services', 'assets', 'modules', 'scripts'):
        shutil.copytree(ROOT / name, root / name, ignore=shutil.ignore_patterns('__pycache__'))
    (root / 'user-settings.json').write_text('{"showWifi":true,"barIconSize":24,"animationsEnabled":false}')
    (root / 'app-usage.json').write_text('{}')
    return root


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-rage-ui-') as folder:
        root = fixture(folder)
        (root / 'external.py').write_text('import json\nfrom pathlib import Path\np=Path(__file__).with_name("user-settings.json")\nd=json.loads(p.read_text());d.update(glassmorphismEnabled=True,glassOpacity=.71,barBackgroundEnabled=False,barSegmentRadius=16);p.write_text(json.dumps(d))\n')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder)
        output = run_qml(root, env, QML)
        summary = re.search(r'RAGE RESULTS (\d+) passed, (\d+) failed', output)
        assert summary and int(summary[1]) >= 10 and int(summary[2]) == 0, output
        saved = json.loads((root / 'user-settings.json').read_text())
        assert saved['glassmorphismEnabled'] and saved['glassStyle'] == 'tinted'
        assert saved['glassOpacity'] == .74 and saved['glassCornerRadius'] == 25
        assert saved['showWifi'] and saved['barIconSize'] == 24
        reload_qml = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot { TestCase { when: true; function test_values() {
CHECKS
console.log("RAGE RELOAD PASS");
} } }
'''
        checks = '\n'.join(f'compare(SettingsStore.{key}, {json.dumps(value)});' for key, value in saved.items()
                           if key.startswith('glass'))
        assert 'RAGE RELOAD PASS' in run_qml(root, env, reload_qml.replace('CHECKS', checks))
        # Old settings, malformed types/ranges and syntactically invalid JSON.
        defaults = json.loads((ROOT / 'user-settings.example.json').read_text())
        checks = '\n'.join(f'compare(SettingsStore.{key}, {json.dumps(value)});' for key, value in defaults.items()
                           if key.startswith('glass'))
        checks += '\nfor (const key of Object.keys(SettingsStore.barSurfaceDefaults)) compare(SettingsStore[key],SettingsStore.barSurfaceDefaults[key]);'
        for data in ('{"showWifi":true}', '{"glassmorphismEnabled":"true","glassStyle":"invalid","glassOpacity":5,"glassCornerRadius":2.2,"barBackgroundEnabled":"false","barOpacity":2,"barSegmentRadius":2.5}', '{broken'):
            (root / 'user-settings.json').write_text(data)
            assert 'RAGE RELOAD PASS' in run_qml(root, env, reload_qml.replace('CHECKS', checks))
    print('PASS: 9 RAGE UI interactions including native provider controls, saved reload, legacy migration, invalid schema/JSON; no compositor mutations')


if __name__ == '__main__':
    main()
