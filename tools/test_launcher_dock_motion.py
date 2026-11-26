#!/usr/bin/env python3
"""Native launcher/dock motion regressions and frame-submit telemetry.

--native shows copied production surfaces with isolated preferences and private,
owner-scoped session rules. It never launches apps or edits global compositor
options. --observe records the old behavior without enforcing the new contracts.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
QML=r'''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "services"
import "modules/main"
ShellRoot {
    id:suite
    property string phase:""
    property string subject:""
    property real started:0
    property var timestamps:[]
    property int resizes:0
    property int moves:0
    property var observations:[]
    function frontend(){return find(launcher.contentItem,"launcherStudio");}
    function find(item,name){if(item.objectName===name)return item;for(const child of item.children || []){const result=find(child,name);if(result)return result;}return null;}
    function content(){return find(dock.contentItem,"dockContents") || firstType(dock.contentItem,"ColumnLayout");}
    function firstType(item,type){if(String(item).indexOf(type)>=0)return item;for(const child of item.children || []){const result=firstType(child,type);if(result)return result;}return null;}
    function sample(which){if(phase && subject===which)timestamps.push(Date.now()-started);}
    function begin(name,which){phase=name;subject=which;timestamps=[];resizes=0;moves=0;started=Date.now();}
    function end(){
        const gaps=[];for(let i=1;i<timestamps.length;i++)gaps.push(timestamps[i]-timestamps[i-1]);
        gaps.sort((a,b)=>a-b);
        const data={phase:phase,frames:timestamps.length,firstSubmitMs:timestamps.length ? timestamps[0] : null,
            p95SubmitGapMs:gaps.length ? gaps[Math.min(gaps.length-1,Math.floor(gaps.length*.95))] : null,
            maxSubmitGapMs:gaps.length ? gaps[gaps.length-1] : null,nativeResizes:resizes,nativeMoves:moves};
        observations.push(data);console.log("SMOOTH SAMPLE",JSON.stringify(data));phase="";return data;
    }
    RusticDock {id:dock;screen:Quickshell.screens[0]}
    property var launcher:fixtureLauncherLoader.item
LAUNCHER_LOADER
    Connections {target:dock;function onWidthChanged(){if(suite.subject==="dock" && suite.phase)suite.resizes++;}function onHeightChanged(){if(suite.subject==="dock" && suite.phase)suite.resizes++;}}
    Connections {target:launcher;function onWidthChanged(){if(suite.subject==="launcher" && suite.phase)suite.resizes++;}function onHeightChanged(){if(suite.subject==="launcher" && suite.phase)suite.resizes++;}}
    property int dockLeft:dock.margins.left
    property int launcherTop:launcher ? launcher.margins.top : 0
    onDockLeftChanged:if(subject==="dock" && phase)moves++
    onLauncherTopChanged:if(subject==="launcher" && phase)moves++
    Connections {target:dock.contentItem.Window.window;function onFrameSwapped(){suite.sample("dock");}}
    Connections {target:launcher ? launcher.contentItem.Window.window : null;function onFrameSwapped(){suite.sample("launcher");}}
    TestCase {
        name:"LauncherDockSmoothMotion";when:true
        function initTestCase(){
            SettingsStore.animationsEnabled=true;SettingsStore.animationStyle="float";
            SettingsStore.lowMemoryShellMode=false;SettingsStore.showDock=true;
            SettingsStore.dockAutoHide=true;SettingsStore.dockRunningApps=false;
            SettingsStore.launcherLayoutMode="spotlight";SettingsStore.launcherBackdropMode="none";
            Store.launcherScreen=dock.screen;Store.launcherVisible=false;
            Store.glassBlurActive=BLUR_ACTIVE;Store.launcherBlurActive=BLUR_ACTIVE;
            wait(500);
        }
        function cleanupTestCase(){Store.launcherVisible=false;SettingsStore.showDock=false;wait(300);console.log("SMOOTH PROFILE",JSON.stringify(suite.observations));console.log("SMOOTH RESULTS",qtest_results.passCount,"passed,",qtest_results.failCount,"failed");}
        function test_dock_expand_collapse_and_reversal(){
            dock.expanded=false;wait(320);
            suite.begin("dock-expand","dock");dock.expanded=true;wait(320);
            let data=suite.end();if(!OBSERVE)compare(data.nativeResizes,0);
            suite.begin("dock-collapse","dock");dock.expanded=false;wait(40);
            if(!OBSERVE)verify(suite.content().opacity>0,"Contents must survive the closing fade");
            wait(280);data=suite.end();if(!OBSERVE)compare(data.nativeResizes,0);
            dock.expanded=true;wait(40);dock.expanded=false;wait(40);dock.expanded=true;wait(320);
            if(!OBSERVE)compare(suite.content().opacity,1);
            SettingsStore.animationsEnabled=false;dock.expanded=false;wait(10);
            if(!OBSERVE)compare(suite.content().opacity,0);
            SettingsStore.animationsEnabled=true;dock.expanded=false;wait(320);
        }
        function test_blur_prepared_before_open(){
            if(OBSERVE)return;
            SettingsStore.launcherBackdropMode="blur";Store.launcherVisible=false;
            const closed=GlassService.requestData();
            compare(closed.launcherBackdropBlur,true);compare(closed.launcherBlur,false);
            Store.launcherVisible=true;compare(GlassService.requestData().launcherBackdropBlur,true);
            Store.launcherVisible=false;SettingsStore.launcherBackdropMode="none";
            compare(GlassService.requestData().launcherBackdropBlur,false);
            compare(GlassService.pending,false); // Service was never started by this isolated scene.
        }
        function test_launcher_resize_and_input_anchor(){
            SettingsStore.launcherLayoutMode="detached";Store.launcherVisible=true;wait(350);
            const view=suite.frontend();view.query="";wait(300);
            let p=launcher.contentItem.mapFromItem(view.inputItem,0,0),anchor=launcher.margins.top+p.y;
            suite.begin("launcher-results-enter","launcher");view.query="a";wait(330);let data=suite.end();
            if(!OBSERVE){compare(data.nativeResizes,0);compare(data.nativeMoves,0);}
            p=launcher.contentItem.mapFromItem(view.inputItem,0,0);compare(launcher.margins.top+p.y,anchor);
            suite.begin("launcher-results-exit","launcher");view.query="";wait(360);data=suite.end();
            if(!OBSERVE){compare(data.nativeResizes,0);compare(data.nativeMoves,0);}
            for(const style of ["spotlight","minimal","classic"]){
                SettingsStore.launcherLayoutMode=style;view.query="";wait(320);
                suite.begin("launcher-resize-"+style,"launcher");view.query="a";wait(330);data=suite.end();
                if(!OBSERVE){compare(data.nativeResizes,0);compare(data.nativeMoves,0);}
            }
            SettingsStore.animationsEnabled=false;view.query="";wait(20);view.query="a";wait(20);
            verify(view.resultsItem.visible);compare(view.resultsItem.opacity,1);
            Store.launcherVisible=false;wait(30);
        }
        function test_warm_launcher_and_low_memory_release(){
            SettingsStore.animationsEnabled=true;SettingsStore.lowMemoryShellMode=false;
            SettingsStore.launcherLayoutMode="launchpad";SettingsStore.launcherBackdropMode="none";
            Store.launcherVisible=true;wait(400);
            const engine=String(suite.frontend().controller);
            Store.launcherVisible=false;wait(260);
            const retained=launcher!==null;
            suite.begin("launchpad-warm-open","launcher");Store.launcherVisible=true;wait(350);suite.end();
            console.log("SMOOTH CACHE",retained,String(suite.frontend().controller)===engine);
            if(!OBSERVE){verify(retained);compare(String(suite.frontend().controller),engine);}
            SettingsStore.lowMemoryShellMode=true;Store.launcherVisible=false;
            tryCompare(fixtureLauncherLoader,"item",null);
            SettingsStore.lowMemoryShellMode=false;wait(30);
            if(!OBSERVE)compare(fixtureLauncherLoader.item,null);
        }
        function test_running_apps_do_not_recreate_unchanged_delegates(){
            if(OBSERVE)return;
            SettingsStore.dockRunningApps=true;dock.expanded=true;wait(350);
            tryCompare(dock,"runningCount",2);
            const app=suite.find(dock.contentItem,"dockRunningApp_motion-fixture");verify(app!==null);
            dock.refreshRunningApps();wait(150);
            compare(suite.find(dock.contentItem,"dockRunningApp_motion-fixture"),app);
            SettingsStore.dockRunningApps=false;dock.expanded=false;wait(300);
        }
    }
}
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native',action='store_true')
    parser.add_argument('--observe',action='store_true')
    parser.add_argument('--source',type=Path,default=ROOT)
    parser.add_argument('--output',type=Path,default=Path('/tmp/rusticq-smooth-motion.json'))
    args=parser.parse_args()
    native=args.native
    if not native:raise SystemExit('Use --native: real PanelWindow/motion coverage requires Wayland. Offline contracts are in test_launcher_studio.py.')
    backend=None;prefix='rusticq-motion-test-'+str(os.getpid())+'-';owner='motion-'+str(os.getpid())
    before={}
    if native:
        spec=importlib.util.spec_from_file_location('motion_blur',args.source/'scripts/rusticq-glass.py');backend=importlib.util.module_from_spec(spec);spec.loader.exec_module(backend)
        caps=backend.capabilities();assert caps['supported'],caps
        before={key:backend.run(['hyprctl','-j','getoption',key]) for key in ('decoration:blur:enabled','decoration:blur:size','decoration:blur:passes')}
        def rule(cleanup=False):
            lua=backend.program(not cleanup,owner,cleanup,True,True,False)
            return lua.replace(json.dumps(backend.TITLES,ensure_ascii=False),json.dumps('^RusticQ Motion Test$')).replace('rusticq-',prefix).replace('_G.__rusticq_rage','_G.__rusticq_motion_test_'+str(os.getpid()))
        assert backend.run(['hyprctl','eval',rule()])=='ok'
    try:
        with tempfile.TemporaryDirectory(prefix='rq-smooth-motion-') as folder:
            target=Path(folder)
            for directory in ('config','components','modules','services','scripts','assets'):
                shutil.copytree(args.source/directory,target/directory,ignore=shutil.ignore_patterns('__pycache__'))
            for filename in ('LauncherOverlay','RusticDock'):
                path=target/'modules/main'/f'{filename}.qml'
                text=path.read_text()
                for name in ('launcher-backdrop','launcher','dock'):text=text.replace('"rusticq-'+name+'"','"'+prefix+name+'"')
                path.write_text(text)
            (target/'user-settings.json').write_text(json.dumps(dict(launcherLayoutMode='spotlight',glassmorphismEnabled=True,rageMode='exclusive',animationsEnabled=True)))
            (target/'app-usage.json').write_text('{}')
            fixture_apps=[dict(appId='motion-fixture',address='0xabcdef123',active=True),dict(appId='motion-other',address='0xabcdef124',active=False)]
            (target/'scripts/rustiq-running-apps.py').write_text('import json\nprint(json.dumps('+repr(dict(ok=True,apps=fixture_apps))+'))\n')
            source=(args.source/'shell.qml').read_text()
            launcher_at=source.index('LauncherOverlay { screen: Store.launcherScreen }')
            start=source.rfind('    MotionLoader {',0,launcher_at)
            opening=source.index('{',start);depth=0;end=opening
            for index in range(opening,len(source)):
                depth+=int(source[index]=='{')-int(source[index]=='}')
                if depth==0:end=index+1;break
            policy=source[start:end]
            if 'id: launcherLoader' in policy:policy=policy.replace('launcherLoader','fixtureLauncherLoader')
            else:policy=policy.replace('MotionLoader {','MotionLoader {\n        id: fixtureLauncherLoader',1)
            policy=policy.replace('screen: Store.launcherScreen','screen: dock.screen')
            scene=QML.replace('LAUNCHER_LOADER',policy).replace('OBSERVE','true' if args.observe else 'false').replace('BLUR_ACTIVE','true' if native and caps.get('globalBlur') else 'false')
            (target/'shell.qml').write_text(scene)
            home=target/'home';home.mkdir()
            env=dict(os.environ,HOME=str(home),QT_QPA_PLATFORM='wayland' if native else 'offscreen',QT_QPA_PLATFORMTHEME='generic',XDG_STATE_HOME=str(target/'state'),XDG_CACHE_HOME=str(target/'cache'))
            if not native:env.update(QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder)
            proc=subprocess.run(['qs','-p',str(target),'--no-color'],env=env,capture_output=True,text=True,timeout=25)
            output=proc.stdout+proc.stderr
            args.output.parent.mkdir(parents=True,exist_ok=True)
            args.output.with_suffix('.log').write_text(output)
            match=re.search(r'SMOOTH PROFILE (\[.*\])',output);result=re.search(r'SMOOTH RESULTS (\d+) passed, (\d+) failed',output)
            assert proc.returncode==0 and match and result and int(result[2])==0,output
            for error in ('TypeError:','ReferenceError:','Binding loop','Unable to assign','Error loading configuration'):assert error not in output,output
            report=dict(native=native,observe=args.observe,profile=json.loads(match[1]),results={'passed':int(result[1]),'failed':int(result[2])},note='Frame-submit intervals in an isolated scene; not whole-desktop FPS/GPU benchmarks.')
            args.output.write_text(json.dumps(report,indent=2)+'\n')
            print(json.dumps(report,indent=2))
    finally:
        if native:
            assert backend.run(['hyprctl','eval',rule(True)])=='ok'
            for key,value in before.items():assert value==backend.run(['hyprctl','-j','getoption',key]),'Global blur changed'


if __name__=='__main__':
    main()
