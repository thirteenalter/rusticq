#!/usr/bin/env python3
"""Launcher Studio real QML views with safe fake desktop-entry execution."""
import json
import os
from pathlib import Path
import re
import tempfile

from test_clock_ui import run_qml
from test_glassmorphism_ui import fixture

QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "config"
import "services"
import "components"
import "modules/main"
import "modules/settings/pages"
ShellRoot {
    id:suite
    Process {id:externalWriter;command:["python3",Quickshell.shellPath("external.py")]}
    property int launches:0
    property QtObject editor:QtObject {property string name:"Example Editor";property string genericName:"Text editor";property string comment:"Edit documents";property string icon:"accessories-text-editor";property var categories:["Development","Utility"];function execute(){suite.launches++;}}
    property QtObject browser:QtObject {property string name:"Example Browser";property string genericName:"Web browser";property string comment:"Browse the web";property string icon:"web-browser";property var categories:["Network"];function execute(){suite.launches++;}}
    property QtObject terminal:QtObject {property string name:"Example Terminal";property string genericName:"Terminal";property string comment:"Command line";property string icon:"utilities-terminal";property var categories:["System"];function execute(){suite.launches++;}}
    Window {
        id:window;visible:true;width:1500;height:1000;color:Theme.background
        MiniLauncher {id:launcher;width:implicitWidth;height:implicitHeight;screenWidth:1500;screenHeight:1000;inputAnchor:Qt.point(400,150);applicationEntries:[suite.editor,suite.browser,suite.terminal]}
        SignalSpy {id:launcherClosed;target:launcher;signalName:"launched"}
        Flickable {
            id:settingsScroll;width:800;height:1000;visible:settingsLoader.active;clip:true
            contentHeight:settingsLoader.item ? settingsLoader.item.implicitHeight : 0
            Loader {id:settingsLoader;width:780;height:item ? item.implicitHeight : 0;active:false;sourceComponent:SettingsLauncherPage {}}
        }
        TestCase {
            name:"LauncherStudio"
            when:true
            property string settingsSearchCheckpoint:""
            function field(){return findChild(launcher,"launcherSearchInput");}
            function init(){
                SettingsStore.applyLauncherSettings(SettingsStore.launcherAppearanceDefaults);
                settingsLoader.active=false;launcher.visible=true;
                SettingsStore.animationsEnabled=false;SettingsStore.lowMemoryShellMode=false;
                SettingsStore.rageMode="adaptive";SettingsStore.glassmorphismEnabled=false;AppUsage.usage=({});AppUsage.recentCommands=[];Store.launcherAnchor=null;
                settingsSearchCheckpoint="";
                launcher.inputAnchor=Qt.point(400,150);launcher.controller.beginSession();window.requestActivate();launcher.focusSearch();wait(30);
            }
            function cleanup(){console.log("STUDIO TEST",qtest_results.functionName,"failed="+qtest_results.failed,"calc="+launcher.controller.calculatorResult,"mode="+launcher.controller.calculatorMode,"calcError="+launcher.controller.calculatorError,"inflight="+launcher.controller.calculatorInFlight,"tools="+launcher.controller.toolRows.length,"settings="+settingsSearchCheckpoint);}
            function cleanupTestCase(){console.log("STUDIO RESULTS",qtest_results.passCount,"passed,",qtest_results.failCount,"failed");}
            function test_all_styles_share_input_and_backend(){
                const input=field(),engine=launcher.controller;
                for(const style of SettingsStore.launcherEnums.launcherLayoutMode){
                    SettingsStore.launcherLayoutMode=style;launcher.query="";wait(30);
                    compare(field(),input);compare(launcher.controller,engine);
                    if(style==="overview" || style==="launchpad") {
                        const grid=findChild(launcher,"launcherResultGrid");verify(grid!==null);
                        verify(grid.width>launcher.inputWidth*.5,"Application grid must retain usable width: "+grid.width);
                    }
                    launcher.query="editor";wait(30);
                    compare(engine.rows.length,1);compare(engine.rows[0],suite.editor);
                    const before=suite.launches;launcher.focusSearch();keyClick(Qt.Key_Return);compare(suite.launches,before+1);
                    verify(launcher.implicitHeight>launcher.inputBlockHeight);
                    launcher.query="no-such-application-zzzzz";wait(30);
                    compare(engine.rows.length,0);verify(launcher.implicitHeight>launcher.inputBlockHeight);
                }
            }
            function test_detached_gap_and_empty_results(){
                SettingsStore.launcherLayoutMode="detached";launcher.query="";wait(30);
                const input=launcher.inputItem;const y=input.y;
                compare(launcher.resultsItem.visible,false);compare(launcher.implicitHeight,64);
                launcher.query="example";wait(30);
                compare(launcher.resultsItem.visible,true);compare(input.y,y);
                compare(launcher.resultsItem.y-(input.y+input.height),SettingsStore.detachedLauncherGap);
                compare(findChild(launcher,"launcherMainMaterial").visible,false);
                launcher.query="";wait(30);compare(launcher.resultsItem.visible,false);compare(input.y,y);
            }
            function test_results_fill_width_without_details(){
                function rightEdge(item){return item.mapToItem(launcher.resultsItem,item.width,0).x;}
                for(const style of SettingsStore.launcherEnums.launcherLayoutMode){
                    SettingsStore.launcherLayoutMode=style;launcher.query="example";wait(30);
                    const viewport=findChild(launcher,"launcherResultsViewport");
                    const detail=findChild(launcher,"launcherDetailPreview");
                    verify(viewport!==null && detail!==null);
                    compare(detail.visible,false);
                    fuzzyCompare(rightEdge(viewport),launcher.resultsItem.width-SettingsStore.launcherPadding,.75);
                }
                SettingsStore.launcherLayoutMode="spotlight";SettingsStore.launcherShowPreview=true;
                launcher.query="editor";wait(30);
                const viewport=findChild(launcher,"launcherResultsViewport"),detail=findChild(launcher,"launcherDetailPreview");
                compare(detail.visible,true);verify(detail.item!==null);
                verify(viewport.width<launcher.resultsItem.width-SettingsStore.launcherPadding*2);
                fuzzyCompare(rightEdge(detail),launcher.resultsItem.width-SettingsStore.launcherPadding,.75);
                SettingsStore.launcherShowPreview=false;wait(30);
                fuzzyCompare(rightEdge(viewport),launcher.resultsItem.width-SettingsStore.launcherPadding,.75);
                SettingsStore.launcherShowPreview=true;launcher.query="no-such-application-zzzzz";wait(30);
                compare(detail.visible,false);fuzzyCompare(rightEdge(viewport),launcher.resultsItem.width-SettingsStore.launcherPadding,.75);
                launcher.query="=2+3";wait(30);
                compare(detail.visible,false);fuzzyCompare(rightEdge(viewport),launcher.resultsItem.width-SettingsStore.launcherPadding,.75);
            }
            function test_header_search_alignment_and_grid_placeholder(){
                for(const density of ["comfortable","compact"]){
                    SettingsStore.uiDensity=density;
                    for(const style of ["compact","clean-hover"]){
                        SettingsStore.launcherLayoutMode=style;launcher.query="editor";wait(30);
                        const title=findChild(launcher,"launcherBrandTitle"),icon=findChild(launcher,"launcherBrandIcon");
                        const header=findChild(launcher,"launcherBrandHeader"),surface=findChild(launcher,"launcherSearchSurface");
                        fuzzyCompare(title.mapToItem(header,0,0).x,icon.width+Theme.contentGap,.75);
                        compare(surface.height,launcher.inputItem.height); // no vertical inset crushing the editor
                        compare(surface.x,SettingsStore.launcherPadding);
                        compare(surface.width,launcher.inputWidth-SettingsStore.launcherPadding*2);
                    }
                    for(const style of ["launchpad","overview"]){
                        SettingsStore.launcherLayoutMode=style;launcher.query="";wait(30);
                        const surface=findChild(launcher,"launcherSearchSurface"),hint=findChild(launcher,"launcherSearchPlaceholder");
                        verify(surface.visible && hint.visible);compare(hint.text,"Search your applications…");
                        fuzzyCompare(surface.x+surface.width/2,launcher.inputWidth/2,.75);
                        verify(field().width>300);verify(field().height>=56);
                        verify(surface.mapToItem(launcher,0,0).y>=SettingsStore.launcherPadding);
                    }
                }
                SettingsStore.uiDensity="comfortable";
            }
            function test_overview_empty_shortcuts_release_their_space(){
                SettingsStore.launcherLayoutMode="overview";launcher.query="";wait(30);
                const sidebar=findChild(launcher,"launcherOverviewSidebar"),viewport=findChild(launcher,"launcherResultsViewport");
                compare(sidebar.visible,false);
                fuzzyCompare(viewport.mapToItem(launcher.resultsItem,0,0).x,SettingsStore.launcherPadding,.75);
                launcher.controller.togglePinned(suite.editor);wait(30);compare(sidebar.visible,true);
                verify(sidebar.width>=200);verify(viewport.width>launcher.inputWidth*.5);
                launcher.controller.togglePinned(suite.editor);wait(30);compare(sidebar.visible,false);
                fuzzyCompare(viewport.mapToItem(launcher.resultsItem,0,0).x,SettingsStore.launcherPadding,.75);
            }
            function test_calculator_and_settings_provider(){
                SettingsStore.launcherLayoutMode="detached";
                launcher.query="=sqrt(144)+8";
                tryCompare(launcher.controller,"calculatorResult","20");
                launcher.query=":settings wifi";
                tryVerify(()=>launcher.controller.toolRows.length>0);
                compare(launcher.controller.toolsMode,true);
                tryVerify(()=>findChild(launcher,"launcherResultGrid")===null);
            }
            function test_rusticq_settings_in_normal_application_search(){
                const engine=launcher.controller;
                for(const query of ["rusticq","rustiq","settings","setting","pengaturan","settings rusticq"]){
                    settingsSearchCheckpoint="query "+query;
                    launcher.query=query;wait(30);
                    compare(engine.toolsMode,false);
                    verify(engine.rows.some(entry=>entry.id==="org.rusticq.Settings"),query);
                }
                for(const style of SettingsStore.launcherEnums.launcherLayoutMode){
                    settingsSearchCheckpoint="style "+style;
                    SettingsStore.launcherLayoutMode=style;launcher.query="RusticQ Settings";wait(30);
                    compare(engine.rows.length,1);
                    const entry=engine.rows[0];compare(entry.name,"RusticQ Settings");
                    settingsSearchCheckpoint="icon "+style;
                    verify(engine.iconSource(entry).length>0);
                    Store.settingsVisible=false;Store.launcherScreen=Quickshell.screens[0];
                    const before=launcherClosed.count;
                    launcher.focusSearch();keyClick(Qt.Key_Return);
                    settingsSearchCheckpoint="opened "+style;
                    compare(Store.settingsVisible,true);compare(Store.settingsTab,"home");
                    compare(Store.settingsScreen,Store.launcherScreen);
                    compare(launcherClosed.count,before+1);
                    Store.settingsVisible=false;
                }
                launcher.query="rusticq";
                settingsSearchCheckpoint="pin and duplicate";
                const entry=engine.rows[0];engine.togglePinned(entry);
                compare(engine.pinned(entry),true);
                engine.rebuild();engine.rebuild();
                compare(engine.allApps.filter(app=>app.id===entry.id).length,1);
                verify(AppUsage.stats(entry).count>0);
            }
            function test_keyboard_grids_pins_and_usage(){
                SettingsStore.launcherLayoutMode="detached";SettingsStore.launcherGridColumns=2;
                launcher.query="example";wait(30);launcher.focusSearch();
                tryCompare(field(),"activeFocus",true);
                keyClick(Qt.Key_Down);compare(launcher.selectedIndex,2);
                keyClick(Qt.Key_Left);compare(launcher.selectedIndex,1);
                launcher.controller.pointerSelection(0,10,10);
                compare(launcher.selectedIndex,1); // Idle pointer cannot undo keyboard selection.
                const chosen=launcher.controller.selected;
                const before=suite.launches;
                keyClick(Qt.Key_Return);compare(suite.launches,before+1);
                compare(AppUsage.stats(chosen).count,1);
                launcher.controller.togglePinned(chosen);compare(launcher.controller.pinned(chosen),true);
                launcher.query="";launcher.controller.category="favorites";wait(30);
                compare(launcher.controller.rows.length,1);compare(launcher.controller.rows[0],chosen);
                launcher.controller.category="recent";compare(launcher.controller.rows[0],chosen);
                AppUsage.noteCommand({label:"Wi-Fi settings",action:"settings",payload:"wifi"});
                compare(launcher.controller.recentCommands.length,1);
                verify(JSON.stringify(AppUsage.usage).indexOf("payload")<0);
                SettingsStore.launcherLayoutMode="raycast";launcher.query="";wait(30);
                const action=findChild(launcher,"launcherProviderAction_settings");verify(action!==null);
                action.forceActiveFocus();tryCompare(action,"activeFocus",true);
                const dismissed=launcherClosed.count;keyClick(Qt.Key_Escape);compare(launcherClosed.count,dismissed+1);
            }
            function test_detached_geometry_materials_and_palette(){
                SettingsStore.launcherLayoutMode="detached";launcher.query="example";
                SettingsStore.rageMode="exclusive";SettingsStore.glassmorphismEnabled=true;
                Store.glassBlurActive=true;Store.launcherBlurActive=true;
                SettingsStore.detachedLauncherInputInheritMaterial=false;
                SettingsStore.detachedLauncherResultsInheritMaterial=false;
                SettingsStore.detachedLauncherInputOpacity=.32;SettingsStore.detachedLauncherResultsOpacity=.63;
                SettingsStore.detachedLauncherInputRadius=7;SettingsStore.detachedLauncherResultsRadius=23;
                wait(30);
                const input=findChild(launcher,"detachedInputMaterial"),results=findChild(launcher,"detachedResultsMaterial");
                fuzzyCompare(input.color.a,.32,.01);fuzzyCompare(results.color.a,.63,.01);
                console.log("MAT alpha/radius",input.color,results.color,input.radius,results.radius);compare(input.radius,7);compare(results.radius,23);
                const fg=String(Theme.foreground),rgb=[input.color.r,input.color.g,input.color.b];
                for(const source of ["aether","gruvbox"]){SettingsStore.colorSource=source;SettingsStore.accentName="red";wait(10);console.log("MAT provider",source,Theme.rageExclusive,Theme.paletteProvider,fg,String(Theme.foreground),input.color.r,rgb[0]);compare(String(Theme.foreground),fg);fuzzyCompare(input.color.r,rgb[0],.0001);}
                SettingsStore.detachedLauncherInputGlassEnabled=false;wait(10);
                console.log("MAT solid",input.color,Theme.background,results.color);compare(input.color,Theme.background);verify(results.color.a<1);compare(Theme.paletteProvider,"rage");
                SettingsStore.detachedLauncherResultsBackgroundEnabled=false;SettingsStore.detachedLauncherResultsOutlineEnabled=false;wait(10);
                compare(results.color.a,0);compare(results.border.width,0);
                compare(findChild(results,"glassSurfaceEffects").item,null);
                SettingsStore.detachedLauncherResultsBackgroundEnabled=true;compare(results.radius,23);
                SettingsStore.detachedLauncherResultWidthMode="custom";SettingsStore.detachedLauncherResultsWidth=800;
                SettingsStore.detachedLauncherResultAlignment="right";wait(10);
                compare(launcher.inputItem.x+launcher.inputItem.width,launcher.resultsItem.x+launcher.resultsItem.width);
                SettingsStore.detachedLauncherExpansionDirection="up";launcher.inputAnchor=Qt.point(400,600);wait(10);
                console.log("MAT up",launcher.inputItem.y,launcher.resultsItem.y,launcher.resultsItem.height,SettingsStore.detachedLauncherGap);compare(launcher.inputItem.y-(launcher.resultsItem.y+launcher.resultsItem.height),SettingsStore.detachedLauncherGap);
            }
            function test_positions_backdrops_and_motion_disabled(){
                for(const style of SettingsStore.launcherEnums.launcherLayoutMode){
                    for(const edge of ["top","bottom","left","right"]){
                        SettingsStore.barPosition=edge;SettingsStore.launcherPosition="follow-bar";
                        for(const size of [[800,600],[1920,1080],[2560,1440]]){
                            const width=LauncherStyle.inputWidth(style,size[0]);
                            const point=LauncherStyle.anchor(style,size[0],size[1],width,100);
                            verify(point.x>=8 && point.y>=8);verify(point.x+width<=size[0]-8);
                        }
                    }
                }
                for(const mode of ["none","dim","blur","dim-blur","focus"]){
                    SettingsStore.launcherBackdropMode=mode;compare(LauncherStyle.backdrop("spotlight"),mode);
                }
                SettingsStore.launcherLayoutMode="detached";SettingsStore.animationsEnabled=true;
                SettingsStore.lowMemoryShellMode=true;launcher.query="example";wait(10);
                compare(launcher.resultsItem.opacity,1);launcher.query="";wait(10);compare(launcher.resultsItem.visible,false);
                SettingsStore.lowMemoryShellMode=false;SettingsStore.launcherAnimationStyle="none";
                launcher.query="example";wait(10);compare(launcher.resultsItem.opacity,1);
                launcher.query="";wait(10);compare(launcher.resultsItem.visible,false);
            }
            function test_provider_files_notes_and_stale_results(){
                SettingsStore.launcherLayoutMode="launchpad";
                launcher.query=":files studio-fixture";wait(30);tryVerify(()=>!launcher.controller.searchBusy);
                tryVerify(()=>launcher.controller.toolRows.length>0);
                console.log("PROVIDER files",JSON.stringify(launcher.controller.toolRows));verify(launcher.controller.toolRows[0].payload.endsWith("studio-fixture.txt"));
                verify(findChild(launcher,"launcherResultGrid")===null);
                launcher.query=":notes studio-fixture";wait(30);tryVerify(()=>launcher.controller.toolRows.some(row=>row.action==="note-toggle"));
                console.log("PROVIDER notes",JSON.stringify(launcher.controller.toolRows));compare(launcher.controller.toolRows[0].action,"note-toggle");
                launcher.query="=sqrt(144)+8";wait(160);launcher.query="=2+3";
                tryCompare(launcher.controller,"calculatorResult","5");
                launcher.query=":settings wifi";wait(175);launcher.query=":settings audio";wait(30);
                tryVerify(()=>launcher.controller.toolRows.some(row=>row.payload==="audio"));
                compare(launcher.controller.toolQuery,"audio");
            }
            function test_validation_live_preferences_and_save(){
                const source=SettingsStore.colorSource,bar=SettingsStore.barMode;
                SettingsStore.setLauncherValue("launcherLayoutMode","detached",false);
                verify(!SettingsStore.setLauncherValue("launcherLayoutMode","invalid",false));
                verify(!SettingsStore.setLauncherValue("launcherBackgroundEnabled",1,false));
                verify(!SettingsStore.setLauncherValue("__proto__",{},false));
                SettingsStore.setLauncherValue("detachedLauncherGap",100,false);compare(SettingsStore.detachedLauncherGap,32);
                SettingsStore.setLauncherValue("launcherWidth",811,false);compare(SettingsStore.launcherUseStyleDefaults,false);
                compare(SettingsStore.colorSource,source);compare(SettingsStore.barMode,bar);
                SettingsStore.launcherUseStyleDefaults=true;SettingsStore.detachedLauncherGap=17;
                SettingsStore.launcherOutlineEnabled=false;SettingsStore.launcherBackdropMode="none";
                SettingsStore.save();wait(120);
            }
            function test_z_settings_gallery_and_independent_reset(){
                launcher.visible=false;settingsLoader.active=true;
                tryVerify(()=>settingsLoader.item!==null);
                waitForRendering(settingsLoader.item);wait(100);
                const card=findChild(settingsLoader.item,"launcherStyle_detached");
                verify(card!==null);
                settingsScroll.contentY=card.mapToItem(settingsLoader.item,0,0).y-50;wait(50);
                mouseClick(card,20,20);
                console.log("STUDIO GALLERY selected",SettingsStore.launcherLayoutMode,"card",card.x,card.y,"scroll",settingsScroll.contentY,"scene",card.mapToItem(window.contentItem,20,20));
                compare(SettingsStore.launcherLayoutMode,"detached");
                SettingsStore.launcherWidth=790;SettingsStore.detachedLauncherGap=30;
                SettingsStore.resetDetachedLauncherAppearance();
                console.log("STUDIO RESET",SettingsStore.detachedLauncherGap,SettingsStore.launcherWidth,SettingsStore.launcherLayoutMode);
                compare(SettingsStore.detachedLauncherGap,10);compare(SettingsStore.launcherWidth,790);
                compare(SettingsStore.launcherLayoutMode,"detached");
            }
            function test_x_external_preferences_keep_session(){
                launcher.query="editor";launcher.focusSearch();SettingsStore.save();wait(120);
                const editor=field(),engine=launcher.controller;
                externalWriter.running=true;tryCompare(externalWriter,"running",false);
                tryCompare(SettingsStore,"launcherLayoutMode","command");
                compare(SettingsStore.launcherWidth,770);compare(SettingsStore.launcherUseStyleDefaults,false);
                compare(launcher.query,"editor");compare(launcher.controller,engine);compare(field(),editor);
                compare(ShellReload.pending,false);compare(field().activeFocus,true);
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-launcher-studio-ui-') as folder:
        root=fixture(folder)
        (root/'user-settings.json').write_text('{}')
        (root/'external.py').write_text('import json\nfrom pathlib import Path\np=Path(__file__).with_name("user-settings.json")\nd=json.loads(p.read_text());d.update(launcherLayoutMode="command",launcherWidth=770,launcherUseStyleDefaults=False);p.write_text(json.dumps(d))\n')
        home=root/'home';home.mkdir()
        documents=home/'Documents';documents.mkdir();(documents/'studio-fixture.txt').write_text('local search fixture')
        state=root/'state';notes=state/'rusticq';notes.mkdir(parents=True)
        # Seed through the production notes helper instead of relying on its schema.
        import subprocess
        subprocess.run(['python3',str(root/'scripts/rusticq-notes.py'),'add','studio-fixture'],env=dict(os.environ,HOME=str(home),XDG_STATE_HOME=str(state)),check=True,capture_output=True)
        env=dict(os.environ,HOME=str(home),QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',
                 QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder,XDG_STATE_HOME=str(root/'state'))
        output=run_qml(root,env,QML)
        match=re.search(r'STUDIO RESULTS (\d+) passed, (\d+) failed',output)
        assert match and int(match[1])>=11 and int(match[2])==0,output
        # Restart reads every validated field through the same FileView, including
        # the auto-geometry preference that legacy size loading used to overwrite.
        saved=json.loads((root/'user-settings.json').read_text())
        reload_qml='\n'.join(['import QtQuick','import QtTest','import Quickshell','import "config"','ShellRoot { TestCase { when:true; function test_reload(){','CHECKS','console.log("STUDIO RELOAD PASS"); } } }'])
        checks='\n'.join('compare(SettingsStore.'+key+','+json.dumps(value)+');' for key,value in saved.items() if key.startswith(('launcher','detachedLauncher')))
        assert 'STUDIO RELOAD PASS' in run_qml(root,env,reload_qml.replace('CHECKS',checks))
        for data,mode,height,row in [({},'spotlight',520,48),({'showWifi':True},'compact',605,56),({'launcherLayoutMode':'clean-hover','launcherWidth':777},'clean-hover',605,56),({'launcherLayoutMode':'spotlight','launcherUseStyleDefaults':True,'launcherWidth':811},'spotlight',520,48),({'launcherLayoutMode':'bad','launcherWidth':False,'detachedLauncherGap':400},'spotlight',520,48)]:
            (root/'user-settings.json').write_text(json.dumps(data))
            checks=f'compare(SettingsStore.launcherLayoutMode,{json.dumps(mode)});compare(SettingsStore.launcherHeight,{height});compare(SettingsStore.launcherRowHeight,{row});'
            checks+='compare(SettingsStore.detachedLauncherGap,10);compare(SettingsStore.launcherUseStyleDefaults,true);'
            assert 'STUDIO RELOAD PASS' in run_qml(root,env,reload_qml.replace('CHECKS',checks))
        (root/'user-settings.json').write_text('{broken')
        assert 'STUDIO RELOAD PASS' in run_qml(root,env,reload_qml.replace('CHECKS','compare(SettingsStore.launcherLayoutMode,"spotlight");compare(SettingsStore.detachedLauncherGap,10);'))
    print('PASS: eleven styles, single controller/input, search, detached gap and calculator/settings providers')


if __name__=='__main__':
    main()
