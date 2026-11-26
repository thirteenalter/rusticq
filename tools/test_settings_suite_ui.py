#!/usr/bin/env python3
"""Run the unified settings UI and palette isolation in an offscreen Qt engine."""
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
from test_glassmorphism_ui import fixture
from test_clock_ui import run_qml

QML='''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "modules/settings"
ShellRoot {
    Component.onCompleted:Store.settingsVisible=true
    SettingsWindow {id:window}
    Window {id:hoverPeer;visible:false;width:320;height:200}
    SettingsDesignTokens {id:hyprDesign;application:"hyprland"}
    TestCase {
        parent:window.contentItem
        name:"SettingsSuite"
        when:true
        property bool captured:false
        function cleanup(){console.log("SUITE TEST "+qtest_results.functionName+" failed="+qtest_results.failed);}
        function cleanupTestCase(){console.log("SUITE RESULTS "+qtest_results.passCount+" passed, "+qtest_results.failCount+" failed");}
        function sidebar(){return findChild(window.contentItem,"rusticq-settings-sidebar");}
        function test_a_default_follows_rusticq_theme(){
            compare(SettingsMaterial.preferences("rusticq").mode,"follow");
            compare(String(sidebar().design.foreground),String(Theme.foreground));
            compare(String(hyprDesign.foreground),String(Theme.foreground));
        }
        function test_all_rusticq_pages_load_with_the_same_material(){
            for(const page of window.pages){
                if(page.key==="compositor")continue;
                window.navigate(page.key,"");wait(70);
                compare(window.activePage.key,page.key);verify(sidebar().design.foreground.a===1);
            }
        }
        function test_material_inheritance_and_rage_palette_isolation(){
            SettingsStore.setSettingsAppearance("shared","mode","rage-dark",false);
            const before=String(sidebar().design.foreground)+String(sidebar().design.base);
            Theme.aetherPalette={background:"#886633",foreground:"#33ff88",accent:"#ffcc00",surface:"#554422"};SettingsStore.colorSource="aether";wait(40);
            compare(String(sidebar().design.foreground)+String(sidebar().design.base),before);
            compare(String(hyprDesign.base),String(sidebar().design.base));
            SettingsStore.setSettingsAppearance("hyprland","enabled",true,false);SettingsStore.setSettingsAppearance("hyprland","mode","neutral-light",false);
            verify(String(hyprDesign.base)!==String(sidebar().design.base));
            SettingsStore.setSettingsAppearance("hyprland","enabled",false,false);compare(String(hyprDesign.base),String(sidebar().design.base));
        }
        function test_fallback_and_transparency_keep_text_opaque(){
            SettingsStore.setSettingsAppearance("shared","mode","rage-dark",false);
            Store.settingsBlurActive=false;verify(sidebar().design.windowColor.a>0.94);
            Store.settingsBlurActive=true;verify(sidebar().design.windowColor.a<0.9);compare(sidebar().design.foreground.a,1);
            SettingsStore.setSettingsAppearance("shared","mode","neutral-dark",false);compare(sidebar().design.windowColor.a,1);
            SettingsStore.setSettingsAppearance("shared","mode","rage-dark",false);
        }
        function test_focused_appearance_pages_do_not_leave_empty_sections(){
            for(const page of ["typography","motion","wallpaper","lockscreen"]){
                window.navigate(page,"");wait(60);
                const editor=findChild(window.contentItem,"appearance-settings-page");verify(editor!==null);compare(editor.sectionFilter,page);
                for(const section of ["typography","motion","wallpaper","lockscreen"]){
                    const item=findChild(editor,"appearance-"+section+"-section");verify(item!==null);compare(item.visible,section===page);
                }
            }
        }
        function test_navigation_search_and_history(){
            window.navigate("bar","");window.navigate("appearance","");window.travel(-1);compare(Store.settingsTab,"bar");window.travel(1);compare(Store.settingsTab,"appearance");
            for(const q of ["gauge","RAGE","keybindings","wallpaper"]){window.query=q;verify(window.matched.length>0,q);}
            window.navigate("window-appearance","Settings Window Appearance");wait(80);compare(window.activePage.key,"window-appearance");
        }
        function test_number_controls_units_keyboard_clamping_and_alignment(){
            function check(actual,expected){if(actual!==expected)console.error("Number control: got "+actual+", expected "+expected);compare(actual,expected);}
            function typeText(text){for(const character of text)keyClick(character.toUpperCase().charCodeAt(0));}
            SettingsStore.setSettingsAppearance("shared","windowOpacity",0.52,false);
            window.navigate("window-appearance","");wait(80);
            const row=findChild(window.contentItem,"settings-appearance-windowOpacity");verify(row!==null,"Opacity row must load");
            const field=findChild(row,"settings-number-field");verify(field!==null,"Number field must load");check(field.text,"52 %");
            const increase=findChild(row,"settings-number-increase");mouseClick(increase);check(SettingsMaterial.preferences("rusticq").windowOpacity,0.53);
            window.contentItem.Window.window.requestActivate();
            field.forceActiveFocus();tryCompare(field,"activeFocus",true);
            keyClick(Qt.Key_A,Qt.ControlModifier);typeText("80");keyClick(Qt.Key_Return);
            check(SettingsMaterial.preferences("rusticq").windowOpacity,0.80);
            keyClick(Qt.Key_Up);check(SettingsMaterial.preferences("rusticq").windowOpacity,0.81);
            keyClick(Qt.Key_A,Qt.ControlModifier);typeText("999");keyClick(Qt.Key_Return);
            check(SettingsMaterial.preferences("rusticq").windowOpacity,1);
            keyClick(Qt.Key_A,Qt.ControlModifier);typeText("invalid");keyClick(Qt.Key_Return);
            check(SettingsMaterial.preferences("rusticq").windowOpacity,1);
            field.focus=false;wait(10);check(field.text,"100 %");
            const other=findChild(window.contentItem,"settings-appearance-sidebarOpacity");
            const otherField=findChild(other,"settings-number-field");
            compare(Math.round(field.mapToItem(window.contentItem,0,0).x),Math.round(otherField.mapToItem(window.contentItem,0,0).x));
        }
        function test_resizing_scrolling_and_stale_search_highlights(){
            const frame=window.contentItem.children.find(c=>c.settingsDesign!==undefined);
            for(const size of [[800,560],[1100,760]]){
                window.contentItem.Window.window.width=size[0];window.contentItem.Window.window.height=size[1];
                window.navigate("window-appearance","");wait(70);
                verify(frame.viewportHeight>200);compare(frame.contentY,0);
                const scroll=findChild(frame,"settings-content-scroll");verify(scroll.contentHeight>scroll.height);
                frame.contentY=scroll.contentHeight-scroll.height;verify(frame.contentY>0);
                window.navigate("window-appearance","Glass material");window.navigate("bar","");wait(100);
                compare(frame.contentY,0);
            }
        }
        function test_override_validation_and_saved_state(){
            SettingsStore.setSettingsAppearance("shared","windowOpacity",-9,false);compare(SettingsMaterial.preferences("rusticq").windowOpacity,0.15);
            SettingsStore.setSettingsAppearance("shared","windowOpacity",0.54,false);
            SettingsStore.setSurfaceMaterial("dock","inherit",false);SettingsStore.setSurfaceMaterial("dock","glass",false);
            const saved=SettingsStore.surfaceMaterialOverrides.dock.glass;SettingsStore.setGlassValue("glassmorphismEnabled",false,false);compare(SettingsStore.surfaceMaterialOverrides.dock.glass,saved);
            SettingsStore.save();
        }
        function test_sidebar_content_stays_inside_its_hit_area(){
            window.navigate("appearance","");wait(70);
            const item=findChild(sidebar(),"settings-navigation-appearance");verify(item!==null);
            const content=item.contentItem;
            for(const child of content.children){
                if(!child.visible)continue;
                const point=child.mapToItem(item,0,0);
                verify(point.x>=0 && point.y>=0 && point.x+child.width<=item.width+0.1 && point.y+child.height<=item.height+0.1,"Sidebar content must fit its interactive row");
            }
        }
        function test_sidebar_hover_clears_outside_rows_and_after_scrolling(){
            const nativeWindow=window.contentItem.Window.window;
            nativeWindow.requestActivate();tryCompare(nativeWindow,"active",true);
            window.navigate("home","");wait(60);
            const side=sidebar(),scroll=findChild(side,"settings-sidebar-scroll");
            const item=findChild(side,"settings-navigation-appearance");
            function expectHover(expected,step){
                try{tryCompare(item,"pointerHovered",expected,700);}
                catch(error){console.error("Sidebar hover "+step+": got "+item.pointerHovered+", expected "+expected+", active="+nativeWindow.active+", visible="+item.visible);throw error;}
            }
            for(const width of [1100,800]){
                nativeWindow.width=width;scroll.contentItem.contentY=0;wait(60);
                mouseMove(window.contentItem,side.width+40,200);wait(10);
                mouseMove(item,item.width/2,item.height/2);expectHover(true,"enter "+width);
                for(const point of [[-1,item.height/2],[item.width+1,item.height/2],[item.width/2,-1],[item.width/2,item.height+1]]){
                    mouseMove(item,point[0],point[1]);expectHover(false,"edge "+point);compare(item.background.color.a,0);
                    mouseMove(item,item.width/2,item.height/2);expectHover(true,"return "+point);
                }
                mouseMove(window.contentItem,side.width+40,200);expectHover(false,"content");compare(item.background.color.a,0);
                mouseMove(item,item.width/2,item.height/2);expectHover(true,"before scroll");
                scroll.contentItem.contentY=scroll.contentItem.contentHeight-scroll.contentItem.height;wait(50);
                if(item.pointerHovered)console.error("Sidebar hover persists after scroll");
                verify(!item.pointerHovered,"Scrolled-out rows must not keep a hover highlight");
                if(width===1100){const search=findChild(side,"settings-sidebar-search");mouseMove(search);verify(!item.pointerHovered);}
            }
            nativeWindow.width=1100;window.navigate("bar","");wait(60);
            const selected=findChild(side,"settings-navigation-bar");mouseClick(selected);mouseMove(window.contentItem,side.width+40,200);
            compare(selected.selected,true);compare(selected.pointerHovered,false);verify(selected.background.color.a>0);
        }
        function test_sidebar_hover_clears_when_window_loses_focus(){
            const nativeWindow=window.contentItem.Window.window;
            nativeWindow.width=1100;nativeWindow.requestActivate();tryCompare(nativeWindow,"active",true);
            window.navigate("home","");const side=sidebar();
            findChild(side,"settings-sidebar-scroll").contentItem.contentY=0;wait(50);
            const item=findChild(side,"settings-navigation-appearance");
            mouseMove(window.contentItem,side.width+40,200);mouseMove(item);tryCompare(item,"pointerHovered",true);
            try{
                hoverPeer.visible=true;hoverPeer.requestActivate();tryCompare(nativeWindow,"active",false);
                compare(item.pointerHovered,false);compare(item.background.color.a,0);
            }finally{hoverPeer.visible=false;nativeWindow.requestActivate();}
        }
        function test_z_capture_suite(){
            Store.settingsBlurActive=true;window.contentItem.Window.window.width=1100;window.contentItem.Window.window.height=760;
            window.navigate("bar","");wait(100);
            const frame=window.contentItem.children.find(c=>c.settingsDesign!==undefined);verify(frame!==undefined);
            mouseMove(window.contentItem,sidebar().width+40,80);wait(20);
            frame.grabToImage(result=>{captured=result.saveToFile("/tmp/rusticq-settings-suite-after.png");});tryCompare(this,"captured",true,3000);
            captured=false;window.navigate("window-appearance","");wait(100);
            mouseMove(window.contentItem,sidebar().width+40,80);wait(20);
            frame.grabToImage(result=>{captured=result.saveToFile("/tmp/rusticq-settings-appearance-after.png");});tryCompare(this,"captured",true,3000);
        }
    }
}
'''

def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-settings-suite-') as folder:
        root=fixture(folder);(root/'home').mkdir();(root/'VERSION').write_text((Path(__file__).resolve().parents[1]/'VERSION').read_text())
        # Use the real local release metadata in screenshots, including its
        # referenced notes; an incomplete fixture otherwise says unavailable.
        repository=Path(__file__).resolve().parents[1]
        for manifest in (root/'config/releases').glob('*.json'):
            for note in json.loads(manifest.read_text()).get('notes',[]):
                destination=root/note;destination.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(repository/note,destination)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder,HOME=str(root/'home'),XDG_CONFIG_HOME=str(root/'home/config'),XDG_STATE_HOME=str(root/'home/state'))
        output=run_qml(root,env,QML)
        assert not re.search(r'Unable to assign|Cannot assign|recursive rearrange',output),output
        result=re.search(r'SUITE RESULTS (\d+) passed, (\d+) failed',output)
        assert result and int(result[1])>=6 and int(result[2])==0,output
        data=json.loads((root/'user-settings.json').read_text());assert data['settingsWindowAppearance']['shared']['windowOpacity']==0.54
        reload_qml='''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {
    TestCase {
        when:true
        function test_saved_preferences_are_loaded_in_a_fresh_engine(){
            compare(SettingsMaterial.preferences("rusticq").windowOpacity,0.54);
            compare(SettingsMaterial.preferences("rusticq").mode,"rage-dark");
            compare(SettingsStore.surfaceMaterialOverrides.dock.glass,false);
            console.log("SETTINGS SUITE RELOAD PASS");
        }
    }
}'''
        assert 'SETTINGS SUITE RELOAD PASS' in run_qml(root,env,reload_qml)
        print('Unified settings suite: every page, material isolation, navigation, fallback and persistence passed.')

if __name__=='__main__':main()
