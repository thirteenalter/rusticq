#!/usr/bin/env python3
"""Real QML studio/launcher interactions offscreen, without a live compositor."""
import json
import os
from pathlib import Path
import re
import sys
import tempfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
from hypr_settings_schema import CATEGORIES, OPTIONS, PRESETS
from hypr_settings_studio import COLLECTIONS
from test_clock_ui import run_qml
from test_glassmorphism_ui import fixture

QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "config"
import "components"
import "services"
import "modules/hyprsettings"
import "modules/settings"
ShellRoot {
    Component.onCompleted: { Store.hyprSettingsVisible=true; }
    HyprSettingsWindow { id: studio }
    Component { id: rusticSettingsComponent; SettingsWindow {} }
    LauncherController { id: launcher; applicationEntries: [] }
    Process { id: external; command: ["python3",Quickshell.shellPath("external.py")] }
    SignalSpy { id: shortcutApproved; target: Store; signalName: "shortcutBackupApproved" }
    SignalSpy { id: shortcutCancelled; target: Store; signalName: "shortcutBackupCancelled" }
    TestCase {
        parent: studio.contentItem
        name: "HyprSettingsStudio"
        when: true
        property bool captured: false
        function descendants(item) {
            let all=[item];
            for (const child of item.children || []) all=all.concat(descendants(child));
            return all;
        }
        function initTestCase() { tryCompare(HyprlandConfigService,"initialized",true,5000); }
        function cleanup() { console.log("HYPR TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); HyprlandConfigService.discard(); }
        function cleanupTestCase() { console.log("HYPR RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
        function test_a_existing_settings_still_loads() {
            const other=rusticSettingsComponent.createObject(null); verify(other!==null);
            compare(other.title,"RusticQ · Settings"); other.destroy();
        }
        function test_launcher_entry_and_single_window_state() {
            launcher.query="hyprland"; wait(100);
            verify(launcher.results.some(e=>e.id==="org.rusticq.HyprlandSettings"));
            const entry=launcher.hyprSettingsEntry;
            Store.settingsVisible=true;
            const serial=Store.hyprSettingsActivation; entry.execute(); entry.execute();
            compare(Store.hyprSettingsActivation,serial+2); verify(Store.settingsVisible); verify(Store.hyprSettingsVisible);
            launcher.applicationEntries=[{id:"org.rusticq.HyprlandSettings.desktop",name:"Duplicate installed entry"}];wait(50);
            compare(launcher.allApps.filter(e=>e.id.indexOf("org.rusticq.HyprlandSettings")===0).length,1);
        }
        function test_b_review_and_apply_refreshes_state() {
            HyprlandConfigService.setOption("decoration:rounding",19);
            HyprlandConfigService.preview(); tryVerify(()=>HyprlandConfigService.previewToken.length>0,3000);
            const review=findChild(studio.contentItem,"hypr-review-dialog"); verify(review!==null); review.close();
            tryCompare(HyprlandConfigService,"busy",false,2000);
            HyprlandConfigService.apply();
            tryVerify(()=>HyprlandConfigService.initialized && !HyprlandConfigService.busy && !HyprlandConfigService.dirty,4000);
            compare(HyprlandConfigService.value("decoration:rounding"),19);
        }
        function test_confirmation_ownership_and_parent_window() {
            shortcutApproved.clear();shortcutCancelled.clear();
            Store.requestShortcutConfirmation("First","target",false,"first",null,"RusticQ · Settings");
            Store.requestShortcutConfirmation("Second","target",false,"second",null,"RusticQ Hyprland Settings");
            compare(shortcutCancelled.count,1);compare(shortcutCancelled.signalArguments[0][0],"first");
            compare(Store.shortcutConfirmWindowTitle,"RusticQ Hyprland Settings");
            Store.approveShortcutConfirmation();compare(shortcutApproved.count,1);compare(shortcutApproved.signalArguments[0][0],"second");
        }
        function test_close_with_a_draft_requires_confirmation() {
            HyprlandConfigService.setOption("decoration:rounding",22);
            studio.contentItem.Window.window.close(); wait(40);
            verify(Store.hyprSettingsVisible);
            const dialog=findChild(studio.contentItem,"hypr-close-dialog");verify(dialog!==null);verify(dialog.visible);
            dialog.close();
        }
        function test_navigation_all_categories() {
            for (const category of HyprlandConfigService.state.categories) {
                studio.switchPage(category.key,""); wait(70); compare(studio.page,category.key);
            }
        }
        function test_local_draft_does_not_apply() {
            HyprlandConfigService.setOption("decoration:rounding",17);
            verify(HyprlandConfigService.dirty); compare(HyprlandConfigService.value("decoration:rounding"),17);
            verify(!HyprlandConfigService.busy); compare(HyprlandConfigService.previewToken,"");
            HyprlandConfigService.discard(); verify(!HyprlandConfigService.dirty);
        }
        function test_sidebar_hover_and_content_are_scoped_to_the_row() {
            studio.switchPage("overview","");wait(60);
            const nativeWindow=studio.contentItem.Window.window,oldWidth=nativeWindow.width;
            nativeWindow.requestActivate();tryCompare(nativeWindow,"active",true);
            const side=findChild(studio.contentItem,"hypr-settings-sidebar");
            const scroll=findChild(side,"settings-sidebar-scroll");
            const item=findChild(side,"settings-navigation-appearance");verify(item!==null);
            for(const width of [1100,800]){
                nativeWindow.width=width;scroll.contentItem.contentY=0;wait(60);
                for(const child of item.contentItem.children){
                    if(!child.visible)continue;
                    const point=child.mapToItem(item,0,0);
                    verify(point.x>=0 && point.y>=0 && point.x+child.width<=item.width+0.1 && point.y+child.height<=item.height+0.1,"Hyprland sidebar content must fit the row");
                }
                mouseMove(studio.contentItem,side.width+40,200);mouseMove(item);tryCompare(item,"pointerHovered",true);
                mouseMove(studio.contentItem,side.width+40,200);tryCompare(item,"pointerHovered",false);compare(item.background.color.a,0);
                const selected=findChild(side,"settings-navigation-overview");compare(selected.selected,true);verify(selected.background.color.a>0);
            }
            nativeWindow.width=oldWidth;
        }
        function test_interactive_slider_and_toggle() {
            studio.switchPage("appearance",""); wait(80);
            const row=findChild(studio.contentItem,"hypr-option-decoration:rounding"); verify(row!==null);
            const slider=descendants(row).find(c=>c.objectName==="settings-suite-slider" && c.from===0 && c.to===20); verify(slider!==undefined);
            verify(slider.width>30); mouseClick(slider,slider.width*0.7,slider.height/2); wait(30);
            verify(HyprlandConfigService.value("decoration:rounding")>10);
            verify(HyprlandConfigService.dirty); verify(!HyprlandConfigService.busy);
            HyprlandConfigService.discard(); studio.switchPage("animations",""); wait(80);
            const toggleRow=findChild(studio.contentItem,"hypr-option-animations:enabled");
            const toggle=descendants(toggleRow).find(c=>c.checked!==undefined && c.indicator!==undefined);
            verify(toggle!==undefined); mouseClick(toggle); compare(HyprlandConfigService.value("animations:enabled"),false);
        }
        function test_record_editor_stages_a_rule() {
            studio.switchPage("window-rules",""); wait(80);
            const editor=findChild(studio.contentItem,"hypr-records-window-rules"); verify(editor!==null);
            editor.begin(-1); wait(40);
            const match=findChild(editor,"hypr-record-field-class"); verify(match!==null);
            match.forceActiveFocus(); match.selectAll(); for (const c of "kitty") keyClick(c); wait(30);
            compare(editor.fields.class,"kitty");
            editor.save(); compare(HyprlandConfigService.draft.records["window-rules"][0].class,"kitty");
            verify(!HyprlandConfigService.busy);
        }
        function test_preset_is_staged() {
            HyprlandConfigService.preset("Minimal"); verify(HyprlandConfigService.dirty);
            compare(HyprlandConfigService.value("decoration:rounding"),6);
        }
        function test_preferences_validation_and_reset() {
            SettingsStore.loadHyprSettingsPreferences({hyprSettingsWidth:-1,hyprSettingsHeight:9999,hyprSettingsTheme:"invalid",hyprSettingsGlass:"yes"});
            compare(SettingsStore.hyprSettingsWidth,800);compare(SettingsStore.hyprSettingsHeight,1800);
            compare(SettingsStore.hyprSettingsTheme,"dark");compare(SettingsStore.hyprSettingsGlass,false);
            SettingsStore.resetHyprSettingsPreferences();compare(SettingsStore.hyprSettingsWidth,1100);compare(SettingsStore.hyprSettingsHeight,760);
        }
        function test_records_survive_navigation() {
            HyprlandConfigService.setRecords("workspaces",[{workspace:"2",monitor:"DP-1",persistent:true}]);
            studio.switchPage("workspaces",""); wait(60); studio.switchPage("appearance",""); wait(60);
            compare(HyprlandConfigService.draft.records.workspaces[0].workspace,"2");
        }
        function test_search_aliases() {
            const sidebar=findChild(studio.contentItem,"hypr-settings-sidebar"); verify(sidebar!==null);
            for (const q of ["rounding","gaps","blur","touchpad","bind"]) { sidebar.query=q; wait(20); verify(sidebar.results.length>0,q); }
            sidebar.query="";
        }
        function test_search_highlight_and_resize() {
            studio.switchPage("appearance","decoration:rounding"); wait(80);
            compare(studio.highlight,"decoration:rounding"); studio.contentItem.Window.window.width=800; studio.contentItem.Window.window.height=560; wait(80);
            compare(studio.width,800); compare(studio.height,560);
        }
        function test_theme_preferences() {
            for (const theme of ["follow","dark","light"]) { SettingsStore.hyprSettingsTheme=theme; wait(30); }
            SettingsStore.hyprSettingsTheme="dark"; studio.contentItem.Window.window.width=800; studio.contentItem.Window.window.height=700; wait(80); studio.saveGeometry();
            compare(SettingsStore.hyprSettingsWidth,studio.width); compare(SettingsStore.hyprSettingsHeight,studio.height);
        }
        function test_z_capture_preview() {
            SettingsStore.setSettingsAppearance("shared","mode","rage-dark",false);Store.hyprSettingsBlurActive=true;
            studio.contentItem.Window.window.width=1100; studio.contentItem.Window.window.height=760;
            studio.switchPage("appearance",""); wait(100);
            findChild(studio.contentItem,"hypr-studio-layout").grabToImage(result=> { captured=result.saveToFile("/tmp/rusticq-hypr-settings-preview.png"); });
            tryCompare(this,"captured",true,3000);
        }
        function test_zz_external_config_change_invalidates_preview() {
            HyprlandConfigService.previewToken="stale-token";
            external.running=true; tryCompare(external,"running",false,2000);
            tryCompare(HyprlandConfigService,"externalChange",true,2000);
            compare(HyprlandConfigService.previewToken,"");
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-hypr-ui-') as folder:
        root=fixture(folder)
        data={'ok':True,'info':{'version':'0.55.0 fixture','editable':True,'format':'lua','path':str(root/'fixture.lua'),'managedPath':str(root/'managed.lua')},
              'options':[dict(o,supported=True,effective=o['default'],reason='') for o in OPTIONS],
              'data':{'options':{},'records':{}}, 'revision':'fixture',
              'categories':[dict(key=k,label=l,group=g,icon=i) for k,l,g,i in CATEGORIES],
              'collections':{k:[dict(key=f[0],label=f[1],type=f[2],default=f[3]) for f in fields] for k,fields in COLLECTIONS.items()},
              'collectionSupport':{k:True for k in COLLECTIONS}, 'presets':PRESETS,'files':{str(root/'fixture.lua'):'fixture'},'clients':[], 'monitors':[], 'plugins':[]}
        (root/'fixture.json').write_text(json.dumps(data))
        (root/'fixture.lua').write_text('-- fixture\n')
        (root/'external.py').write_text('from pathlib import Path\np=Path(__file__).with_name("fixture.lua")\np.write_text(p.read_text()+"-- externally changed\\n")\n')
        (root/'scripts/rusticq-compositor-config.py').write_text('''import json,sys
from pathlib import Path
p=Path(__file__).parents[1]/"fixture.json"
s=json.loads(p.read_text()); action=sys.argv[1]
r={"ok":True,"snapshots":[]}
if action=="studio-status": r=s
elif action=="studio-preview": r.update(token="fixture-token",diff="+ staged fixture configuration")
elif action=="studio-apply":
    values=json.loads(sys.argv[sys.argv.index("--values")+1])
    s['data']={k:values[k] for k in ('options','records')};p.write_text(json.dumps(s))
print(json.dumps(r))
''')
        (root/'home').mkdir()
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder,
                 XDG_CONFIG_HOME=str(root/'home/config'),XDG_STATE_HOME=str(root/'home/state'),HOME=str(root/'home'))
        output=run_qml(root,env,QML)
        summary=re.search(r'HYPR RESULTS (\d+) passed, (\d+) failed',output)
        assert summary and int(summary[1])>=10 and int(summary[2])==0,output
        settings=json.loads((root/'user-settings.json').read_text())
        assert settings['hyprSettingsWidth']==800 and settings['hyprSettingsHeight']==700
        print('Hyprland studio UI: navigation, launcher, drafts, presets, sizing and persistence passed.')


if __name__=='__main__': main()
