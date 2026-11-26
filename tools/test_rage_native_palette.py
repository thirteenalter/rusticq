#!/usr/bin/env python3
"""Native provider isolation, material budgets, geometry and file persistence.

Runs real reactive QML offscreen. Aether writes target a temporary HOME only.
No live compositor, desktop configuration or user preference is changed.
"""
import json
import os
from pathlib import Path
import re
import tempfile

from test_clock_ui import run_qml
from test_glassmorphism_ui import fixture

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "config"
import "components"
import "modules/bar"
ShellRoot {
    FileView { id:aether;path:Theme.aetherPath;blockLoading:true }
    Window {
        visible:true;width:850;height:700
        GlassSurface { id:outer;width:400;height:400;surfaceRole:"popup" }
        BarWifi { id:wifi;standalone:true;width:368;height:400 }
        BarBluetooth { id:bluetooth;standalone:true;x:420;width:368;height:375 }
        BarSurface { id:bar;y:500;width:400;height:48;barLayer:"outer";baseColor:Theme.background }
        TestCase {
            name:"RageNativePalette"
            when:true
            readonly property var tokens: TOKEN_NAMES
            function snapshot() { return JSON.stringify(tokens.map(key=>String(Theme[key]))); }
            function init() {
                SettingsStore.applyGlassSettings(SettingsStore.glassDefaults);
                SettingsStore.applyBarSurfaceSettings(SettingsStore.barSurfaceDefaults);
                SettingsStore.animationsEnabled=false;
                SettingsStore.lowMemoryShellMode=false;
                SettingsStore.rageMode="exclusive";
                Store.glassBlurActive=true;
            }
            function cleanup() { console.log("NATIVE PALETTE TEST",qtest_results.functionName,"failed="+qtest_results.failed); }
            function cleanupTestCase() { console.log("NATIVE PALETTE RESULTS",qtest_results.passCount,"passed,",qtest_results.failCount,"failed"); }
            function test_all_semantic_colors_ignore_external_sources() {
                for(const palette of ["obsidian","pearl","pure-crystal","graphite-frost"]) {
                    SettingsStore.ragePalette=palette;
                    for(const glass of [true,false]) {
                        SettingsStore.glassmorphismEnabled=glass;
                        for(const style of ["frosted","crystal","tinted"]) {
                            SettingsStore.glassStyle=style;
                            const before=snapshot(), material=outer.color,barColor=bar.color;
                            for(const extreme of ["#ff0000","#00ff00","#ffff00"]) {
                                Theme.parseAether('background="'+extreme+'"\\nforeground="'+extreme+'"\\naccent="'+extreme+'"\\ncolor1="'+extreme+'"\\ncolor2="'+extreme+'"\\ncolor3="'+extreme+'"\\ncolor4="'+extreme+'"');
                                for(const source of ["aether","gruvbox"]) {
                                    SettingsStore.colorSource=source;
                                    for(const accent of ["orange","green","blue","purple"]) {
                                        SettingsStore.accentName=accent;
                                        compare(Theme.paletteProvider,"rage");
                                        compare(snapshot(),before,palette+" "+style+" "+source+" "+accent);
                                        compare(outer.color,material);compare(bar.color,barColor);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            function test_watched_aether_file_does_not_change_native_palette() {
                SettingsStore.glassmorphismEnabled=true;
                SettingsStore.colorSource="aether";
                const before=snapshot();
                for(const extreme of ["#ff0000","#00ff00","#ffff00"]) {
                    aether.setText('background="'+extreme+'"\\nforeground="#ffffff"\\naccent="'+extreme+'"');
                    tryVerify(()=>Theme.aetherPalette.background===extreme);
                    compare(snapshot(),before);
                }
                SettingsStore.rageMode="adaptive";
                compare(SettingsStore.colorSource,"aether");
                compare(Theme.paletteProvider,"aether");compare(Theme.background,"#ffff00");
                SettingsStore.colorSource="gruvbox";
                compare(Theme.paletteProvider,"gruvbox");compare(Theme.background,"#282828");
            }
            function test_material_layers_preserve_foreground_and_geometry() {
                SettingsStore.glassmorphismEnabled=true;
                SettingsStore.glassCornerRadius=16;
                for(const style of ["frosted","crystal","tinted"]) {
                    SettingsStore.setGlassPreset(style);
                    compare(SettingsStore.glassCornerRadius,16);
                    verify(Theme.glassPrimary.a>=.15 && Theme.glassPrimary.a<=.51);
                    verify(Theme.glassPopup.a>=.45 && Theme.glassPopup.a<=.65);
                    verify(Theme.glassCard.a>=.03 && Theme.glassCard.a<=.08);
                    verify(Theme.glassLighting.a<=.06);
                    verify(Theme.glassShadowColor.a<=.20);
                    verify(Math.abs(Theme.glassPrimary.r-Theme.glassPrimary.g)<.01);
                    compare(Theme.foreground,"#f5f5f7");compare(outer.opacity,1);
                    compare(wifi.color.a,0);compare(wifi.border.width,0);
                    compare(bluetooth.color.a,0);compare(bluetooth.border.width,0);
                }
                SettingsStore.setBarSurfacePreset("naked");
                compare(bar.color.a,0);compare(bar.border.width,0);
                tryCompare(findChild(bar,"glassSurfaceEffects"),"item",null);
                Store.glassBlurActive=false;
                verify(Theme.glassPrimary.a>=.85);
                compare(SettingsStore.glassOpacity,.50);
                compare(Theme.glassAuthentication.a,1);
            }
            function test_glass_reset_and_bar_material_do_not_reset_provider() {
                SettingsStore.ragePalette="pearl";
                SettingsStore.barGlassEnabled=false;
                SettingsStore.glassmorphismEnabled=false;
                compare(bar.color,Theme.background);
                const before=snapshot();
                SettingsStore.colorSource="aether";
                compare(snapshot(),before);
                SettingsStore.resetGlassSettings();
                compare(SettingsStore.rageMode,"exclusive");compare(SettingsStore.ragePalette,"pearl");
                verify(!SettingsStore.setGlassValue("rageMode","external"));
                verify(!SettingsStore.setGlassValue("ragePalette","__proto__"));
                SettingsStore.save();
            }
            function test_base_background_and_text_are_opaque_with_external_alpha() {
                Theme.parseAether('background="#10203040"\\nforeground="#10ffffff"');
                SettingsStore.rageMode="adaptive";SettingsStore.colorSource="aether";
                compare(Theme.background.a,1);compare(Theme.foreground.a,1);
                SettingsStore.rageMode="exclusive";
                compare(Theme.background,"#19191c");compare(Theme.foreground,"#f5f5f7");
            }
            function test_z_save_native_provider() {
                SettingsStore.rageMode="exclusive";
                SettingsStore.ragePalette="pearl";
                SettingsStore.save();
                wait(50);
            }
        }
    }
}
'''


def main():
    tokens = re.findall(r'readonly property color (\w+):', (ROOT/'config/Theme.qml').read_text())
    with tempfile.TemporaryDirectory(prefix='rage-native-palette-') as folder:
        root = fixture(folder)
        home = root/'home'
        aether = home/'.config/aether/theme'
        aether.mkdir(parents=True)
        (aether/'colors.toml').write_text('background="#102030"\nforeground="#ffffff"\n')
        env = dict(os.environ, HOME=str(home), QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder, XDG_STATE_HOME=str(root/'state'))
        output = run_qml(root, env, QML.replace('TOKEN_NAMES',json.dumps(tokens)))
        match = re.search(r'NATIVE PALETTE RESULTS (\d+) passed, (\d+) failed', output)
        assert match and int(match[1])>=6 and int(match[2])==0, output
        data = json.loads((root/'user-settings.json').read_text())
        assert data['rageMode']=='exclusive' and data['ragePalette']=='pearl'
        check = '''import QtQuick
import Quickshell
import "config"
ShellRoot { Timer { interval:80;running:true;onTriggered:{
if(SettingsStore.rageMode!=="exclusive" || SettingsStore.ragePalette!=="pearl" || Theme.paletteProvider!=="rage") throw Error("Native provider persistence failed");
console.log("PROVIDER RELOAD PASS");Qt.quit(); } } }'''
        assert 'PROVIDER RELOAD PASS' in run_qml(root,env,check)
    print(f'PASS: {len(tokens)} semantic tokens; 4 native palettes, 3 styles, glass on/off, extreme external updates, watched Aether file, solid bar, layers, geometry, save/reload')


if __name__=='__main__':
    main()
