#!/usr/bin/env python3
"""Actual bar decorations, geometry, foreground retention and synchronized UI.

Uses the established headless PanelWindow/device fixtures, not a second bar.
"""
import json
import os
from pathlib import Path
import re
import tempfile

from test_bar_padding_ui import prepare
from test_clock_ui import run_qml

QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "modules/main"
import "modules/settings/pages"
ShellRoot {
    QtObject { id: wide; property int width:1440;property int height:980;property string name:"wide" }
    QtObject { id: narrow;property int width:900;property int height:700;property string name:"narrow" }
    Bar { id:first;screen:wide }
    Bar { id:second;screen:narrow }
    Window {
        id:scene;visible:true;width:1450;height:1050;color:"#f1e8d6"
        Flickable {
            id:scroll;x:400;y:150;width:700;height:870;clip:true;contentHeight:editor.implicitHeight
            BarSurfaceSettings { id:editor;width:680 }
        }
        Loader { id:otherEditor;active:false;sourceComponent:BarSurfaceSettings {} }
        GlassSurface { id:independentPanel;width:200;height:80;y:800 }
        TestCase {
            when:true
            readonly property var keys:["barBackgroundEnabled","barOutlineEnabled","barSegmentBackgroundEnabled",
                "barSegmentOutlineEnabled","barModuleBackgroundEnabled","barModuleOutlineEnabled"]
            function all(item) { let list=[item];for(const c of item.children) list=list.concat(all(c));return list; }
            function surfaces(bar) { return all(bar.contentItem).filter(c => c.barLayer !== undefined); }
            function outer(bar) { return findChild(bar.contentItem,"barOuterSurface"); }
            function controls(name) { const c=findChild(editor,name);verify(c!==null,name);return c; }
            function click(name) {
                const c=controls(name);
                scroll.contentY=Math.max(0,Math.min(scroll.contentHeight-scroll.height,c.mapToItem(editor,0,0).y-70));
                wait(10);mouseClick(c);
            }
            function initTestCase() {
                first.contentItem.parent=scene.contentItem;
                second.contentItem.parent=scene.contentItem;
                second.contentItem.y=100;
            }
            function init() {
                SettingsStore.animationsEnabled=false;
                SettingsStore.applyBarSurfaceSettings(SettingsStore.barSurfaceDefaults);
                SettingsStore.glassmorphismEnabled=true;
                SettingsStore.barMode="separated";SettingsStore.barPosition="top";
                Store.glassBlurActive=true;
                otherEditor.active=false;
                wait(30);
            }
            function cleanup() { console.log("BAR SURFACE TEST "+qtest_results.functionName+" failed="+qtest_results.failed); }
            function cleanupTestCase() { console.log("BAR SURFACE RESULTS "+qtest_results.passCount+" passed, "+qtest_results.failCount+" failed"); }
            function test_default_separated_has_no_rectangular_frame() {
                compare(outer(first).color.a,0);compare(outer(first).border.width,0);
                compare(findChild(outer(first),"glassSurfaceEffects").item,null);
                verify(surfaces(first).some(c => c.barLayer==="segment" && c.visible && c.color.a>0));
            }
            function test_professional_original_structure_and_geometry() {
                SettingsStore.barMode="professional";
                SettingsStore.glassmorphismEnabled=false;
                for(const edge of ["top","bottom","left","right"]) {
                    SettingsStore.barPosition=edge;wait(35);
                    const rail=outer(first);
                    compare(rail.color,Theme.background);compare(rail.radius,0);
                    compare(rail.border.width,1);compare(rail.border.color,Theme.borderaccent);
                    verify(!surfaces(first).some(s => s.barLayer==="segment" && s.visible));
                    const width=first.width,height=first.height;
                    SettingsStore.glassmorphismEnabled=true;
                    compare(rail.radius,0);compare(first.width,width);compare(first.height,height);
                    SettingsStore.glassmorphismEnabled=false;
                }
            }
            function test_all_visibility_combinations_independent_and_geometric() {
                const width=first.width,height=first.height;
                for(let mask=0;mask<64;mask++) {
                    keys.forEach((key,i) => SettingsStore[key]=!!(mask & (1<<i)));
                    for(const bar of [first,second]) {
                        for(const s of surfaces(bar)) {
                            if(!s.decorationBackgroundEnabled && s.feedbackColor.a===0) compare(s.color.a,0,s.barLayer);
                            if(!s.decorationOutlineEnabled && s.feedbackBorderWidth===0) compare(s.border.width,0,s.barLayer);
                            if(!s.decorationBackgroundEnabled || !s.decorationOutlineEnabled) compare(s.reflectionsEnabled,false);
                            if(!s.decorationBackgroundEnabled) compare(s.shadowsEnabled,false);
                        }
                    }
                    compare(first.width,width);compare(first.height,height);
                }
                compare(independentPanel.color,Theme.glassPrimary);
            }
            function test_all_layouts_edges_and_materials_naked_keeps_foreground() {
                for(const mode of SettingsStore.spacingModes) for(const edge of ["top","bottom","left","right"]) {
                    SettingsStore.barMode=mode;SettingsStore.barPosition=edge;
                    SettingsStore.applyBarSurfaceSettings(SettingsStore.barSurfaceDefaults);wait(35);
                    const w=first.width,h=first.height;
                    SettingsStore.setBarSurfacePreset("naked");wait(35);
                    for(const global of [false,true]) for(const local of [false,true]) {
                        SettingsStore.glassmorphismEnabled=global;SettingsStore.barGlassEnabled=local;
                        compare(Theme.barGlassActive,global && local);
                        for(const s of surfaces(first)) if(s.feedbackColor.a===0) {
                            compare(s.color.a,0);compare(s.border.width,0);
                            compare(findChild(s,"glassSurfaceEffects").item,null);
                        }
                    }
                    if(first.width!==w || first.height!==h) console.error("GEOMETRY",mode,edge,first.width,w,first.height,h);
                    compare(first.width,w);compare(first.height,h);
                    if(!all(first.contentItem).some(c => c.text && c.visible && c.opacity===1)) console.error("FOREGROUND",mode,edge);
                    verify(all(first.contentItem).some(c => c.text && c.visible && c.opacity===1));
                    verify(first.visible);compare(first.color.a,0);
                    compare(outer(first).color,outer(second).color);
                }
            }
            function test_floating_segments_custom_radius_and_other_panels() {
                SettingsStore.setBarSurfacePreset("floating");SettingsStore.barSegmentRadius=16;wait(20);
                compare(outer(first).color.a,0);compare(outer(first).border.width,0);
                for(const s of surfaces(first)) {
                    if(s.barLayer==="segment" && s.visible) { compare(s.radius,16);verify(s.color.a>0);compare(s.border.width,0); }
                    if(s.barLayer==="module" && s.feedbackColor.a===0) { compare(s.color.a,0);compare(s.border.width,0); }
                }
                compare(independentPanel.color,Theme.glassPrimary);
                SettingsStore.setBarSurfacePreset("naked");SettingsStore.setBarSurfacePreset("floating");
                compare(SettingsStore.barSegmentRadius,16);
                SettingsStore.barCapsuleGeometry=true;
                const segment=surfaces(first).find(c => c.barLayer==="segment" && c.visible);
                compare(segment.radius,Math.min(segment.width,segment.height)/2);
                SettingsStore.barCapsuleGeometry=false;compare(segment.radius,16);
                SettingsStore.barGlassEnabled=false;compare(segment.color,Theme.surface);compare(segment.radius,16);
            }
            function test_presets_do_not_change_palette_geometry_or_global_rage() {
                SettingsStore.barSegmentRadius=16;
                const source=SettingsStore.colorSource,accent=Theme.accent,edge=SettingsStore.barPosition;
                for(const preset of ["rail","borderless","floating","outline","naked","original"]) {
                    verify(SettingsStore.setBarSurfacePreset(preset));
                    compare(SettingsStore.glassmorphismEnabled,true);compare(SettingsStore.colorSource,source);
                    compare(Theme.accent,accent);compare(SettingsStore.barSegmentRadius,16);compare(SettingsStore.barPosition,edge);
                }
                SettingsStore.setBarSurfacePreset("rail");verify(outer(first).color.a>0 && outer(first).color.a<1);verify(outer(first).border.width>0);
                SettingsStore.setBarSurfacePreset("borderless");verify(outer(first).color.a>0);compare(outer(first).border.width,0);
                SettingsStore.setBarSurfacePreset("outline");compare(outer(first).color.a,0);compare(outer(first).border.width,1);
                SettingsStore.setGlassPreset("crystal");compare(SettingsStore.barBackgroundEnabled,false);
                verify(!SettingsStore.setBarSurfaceValue("showWifi",false));
                verify(!SettingsStore.setBarSurfaceValue("barOutlineEnabled","false"));
                verify(!SettingsStore.setBarSurfaceValue("barOpacity",NaN));
            }
            function test_synchronized_editors_enabled_without_rage_and_slider_commit() {
                SettingsStore.glassmorphismEnabled=false;
                otherEditor.active=true;tryVerify(() => otherEditor.item!==null);
                click("barBackgroundEnabledToggle");compare(SettingsStore.barBackgroundEnabled,false);
                compare(findChild(otherEditor.item,"barBackgroundEnabledToggle").checked,false);
                verify(controls("barOutlineEnabledToggle").enabled);
                click("barOutlineEnabledToggle");compare(outer(first).border.width,0);
                const slider=controls("barSegmentRadiusSlider");
                const snapshot=SettingsStore.settingsSnapshot;
                slider.preview(16);compare(SettingsStore.barSegmentRadius,16);compare(SettingsStore.settingsSnapshot,snapshot);
                slider.commit(16);verify(SettingsStore.settingsSnapshot!==snapshot);
                SettingsStore.setBarSurfacePreset("floating");
                SettingsStore.setBarSurfaceValue("barSegmentRadius",16);
                wait(100);
                scene.color="#f1e8d6";grabImage(scene.contentItem).save("/tmp/rusticq-rage-bar-light.png");
                scene.color="#101114";grabImage(scene.contentItem).save("/tmp/rusticq-rage-bar-dark.png");
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rq-bar-surfaces-') as folder:
        root=Path(folder);prepare(root)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',
                 QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder,DBUS_SESSION_BUS_ADDRESS='unix:path='+folder+'/missing')
        output=run_qml(root,env,QML)
        result=re.search(r'BAR SURFACE RESULTS (\d+) passed, (\d+) failed',output)
        assert result and int(result[1])>=6 and int(result[2])==0,output
        saved=json.loads((root/'user-settings.json').read_text())
        assert saved['barSegmentRadius']==16 and not saved['barBackgroundEnabled']
        assert saved['barSegmentBackgroundEnabled'] and not saved['barModuleBackgroundEnabled']
        source='''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot { TestCase { when:true; function test_reload() {
compare(SettingsStore.barBackgroundEnabled,false);compare(SettingsStore.barOutlineEnabled,false);
compare(SettingsStore.barSegmentBackgroundEnabled,true);compare(SettingsStore.barSegmentRadius,16);
compare(SettingsStore.barModuleBackgroundEnabled,false);console.log("BAR SURFACE RELOAD PASS");
} } }
'''
        assert 'BAR SURFACE RELOAD PASS' in run_qml(root,env,source)
    print('PASS: 64 visibility combinations; 5 layouts × 4 edges; two monitors; independent materials/geometry; live controls and reload')


if __name__=='__main__':
    main()
