#!/usr/bin/env python3
"""Real Wayland Launcher Studio captures and optional keyboard verification.

Explicit --run temporarily covers one output with a detailed test background.
Only copied source, isolated preferences, test namespaces and private Lua rule
names are used. No application is executed and global compositor settings stay
unchanged. All temporary native rules/windows are released on exit.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
STYLES=['compact','clean-hover','spotlight','raycast','launchpad','fluent','minimal','classic','overview','command','detached']
QML=r'''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "config"
import "services"
import "modules/main"
ShellRoot {
    id:suite
    property bool backendMaterial:true
    property bool backendBackdrop:false
    property bool applicationBackground:false
    PanelWindow {
        id:background;screen:Quickshell.screens[0]
        visible:!suite.applicationBackground
        WlrLayershell.namespace:"TEST_PREFIXbackground"
        WlrLayershell.layer:WlrLayer.Top
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        exclusionMode:ExclusionMode.Ignore
        anchors{top:true;bottom:true;left:true;right:true}
        color:"#17191f"
        mask:Region {}
        Canvas {
            anchors.fill:parent
            onPaint:{
                const c=getContext("2d"), w=width,h=height;
                c.fillStyle="#1b202a";c.fillRect(0,0,w,h);
                const colors=["#294b70","#557a75","#796350","#625378"];
                for(let x=0;x<w;x+=160){c.fillStyle=colors[Math.floor(x/160)%4];c.fillRect(x,0,64,h);}
                c.lineWidth=1;c.strokeStyle="#a7b5c7";
                for(let y=0;y<h;y+=18){c.beginPath();c.moveTo(0,y);c.lineTo(w,y+120);c.stroke();}
                c.fillStyle="#eef0f5";c.font="14px monospace";
                for(let y=90;y<h;y+=150)c.fillText("Detailed native test background · 0123456789 · source detail stays sharp outside the launcher",24,y);
            }
        }
    }
    FloatingWindow {
        visible:suite.applicationBackground
        title:"RusticQ Studio Validation"
        implicitWidth:Math.min(1600,background.screen.width-80)
        implicitHeight:Math.min(940,background.screen.height-100)
        color:"#fafafa"
        Column {
            anchors.fill:parent;anchors.margins:28;spacing:8
            Text {text:"Native application behind Spotlight";color:"#18181c";font.pixelSize:26}
            Repeater {model:45
                delegate:Text {required property int index;text:"Text row "+index+"  ·  ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789   /usr/share/applications";color:index%2 ? "#303038" : "#64646c";font.family:"monospace";font.pixelSize:16}
            }
        }
    }
    LauncherOverlay {id:overlay;screen:background.screen}
    RusticDock {id:dock;screen:background.screen}
    function find(item,name){if(item.objectName===name)return item;for(const child of item.children || []){const result=find(child,name);if(result)return result;}return null;}
    function frontend(){return find(overlay.contentItem,"launcherStudio");}
    IpcHandler {
        target:"studio-validation"
        function frame(style:string,query:string,backdrop:string):bool {
            if(SettingsStore.launcherEnums.launcherLayoutMode.indexOf(style)<0 || SettingsStore.launcherEnums.launcherBackdropMode.indexOf(backdrop)<0)return false;
            SettingsStore.applyLauncherSettings(SettingsStore.launcherAppearanceDefaults);
            SettingsStore.launcherLayoutMode=style;
            SettingsStore.launcherBackdropMode=backdrop;
            SettingsStore.animationsEnabled=true;
            SettingsStore.rageMode="exclusive";SettingsStore.ragePalette="obsidian";
            SettingsStore.glassmorphismEnabled=true;
            Store.launcherScreen=background.screen;
            Store.launcherVisible=true;
            frontend().revealPreview=false;
            frontend().query=query;
            frontend().focusSearch();
            return true;
        }
        function blur(material:bool,backdrop:bool):void {
            Store.glassBlurActive=material;
            Store.launcherBlurActive=material || backdrop;
            Store.launcherBackdropBlurActive=backdrop;
        }
        function query(value:string):void {frontend().query=value;frontend().focusSearch();}
        function option(key:string,value:string):bool {try{return SettingsStore.setLauncherValue(key,JSON.parse(value),false);}catch(error){return false;}}
        function close():void {Store.launcherVisible=false;}
        function showDock(expanded:bool):void {
            Store.launcherVisible=false;SettingsStore.showDock=true;SettingsStore.dockAutoHide=true;dock.expanded=expanded;
        }
        function hideDock():void {SettingsStore.showDock=false;}
        function appBackground(value:bool):void {suite.applicationBackground=value;}
        function shortcuts(value:bool):void {
            const usage={};
            if(value) frontend().controller.allApps.slice(0,3).forEach((entry,index)=>{
                usage[AppUsage.keyOf(entry)]={count:3-index,last:Date.now()-index*1000,pinned:index<2};
            });
            AppUsage.usage=usage;
        }
        function metrics():string {
            const view=frontend(),field=find(view,"launcherSearchInput"),input=view.inputItem,result=view.resultsItem,grid=find(view,"launcherResultGrid");
            const rect=item=>{const p=overlay.contentItem.mapFromItem(item,0,0);return {x:overlay.margins.left+p.x,y:overlay.margins.top+p.y,width:item.width,height:item.height};};
            const dockSurface=find(dock.contentItem,"dockSurface");
            const dp=dockSurface ? dock.contentItem.mapFromItem(dockSurface,0,0) : Qt.point(0,0);
            return JSON.stringify({style:SettingsStore.launcherLayoutMode,query:view.query,visible:overlay.visible,logicalVisible:Store.launcherVisible,
                count:view.controller.rows.length,apps:view.controller.allApps.length,calculator:view.controller.calculatorResult,selectedIndex:view.selectedIndex,gridWidth:grid ? grid.width : 0,
                input:rect(input),results:rect(result),surface:rect(view),resultsVisible:result.visible,
                dock:{visible:dock.visible,x:dock.margins.left+dp.x,y:background.screen.height-dock.margins.bottom-dock.height+dp.y,width:dockSurface ? dockSurface.width : 0,height:dockSurface ? dockSurface.height : 0},
                window:{x:overlay.margins.left,y:overlay.margins.top,width:overlay.width,height:overlay.height},
                nativeFocus:field.Window.active,editorFocus:field.activeFocus,controller:String(view.controller),editor:String(field),
                screen:background.screen.name,backdrop:overlay.backdropMode,palette:Theme.paletteProvider,foreground:String(Theme.foreground),background:String(Theme.background)});
        }
    }
    Timer {interval:180000;running:true;onTriggered:Qt.quit()}
}
'''


def pixel_proof(output, captures, blur_available=True):
    from PIL import Image, ImageChops, ImageStat
    by_name={entry['name']:entry for entry in captures}
    base=Image.open(output/'closed.png').convert('RGB')
    proof={'outside':{},'outsideVisualSurfaces':{},'dock':{},'detachedGap':{},'nativeBlur':{}}
    for name, data in by_name.items():
        if name.startswith('dock-'):
            frame=Image.open(output/(name+'.png')).convert('RGB')
            rect=data['dock'];assert rect['visible']
            delta=ImageChops.difference(base,frame)
            x,y,w,h=(round(rect[key]) for key in ('x','y','width','height'))
            delta.paste((0,0,0),(x-1,y-1,x+w+1,y+h+1))
            proof['dock'][name]={'surface':rect,'outsideChangedBounds':delta.getbbox()}
            assert delta.getbbox() is None,('Dock left a rectangular fill/blur halo',name,delta.getbbox())
            if name!='dock-expanded':assert w==82 and h==18
            continue
        if data['backdrop']!='none' or data.get('crop') or not data['logicalVisible']:
            continue
        frame=Image.open(output/(name+'.png')).convert('RGB')
        delta=ImageChops.difference(base,frame)
        rect=data['window'];x,y,w,h=(int(rect[key]) for key in ('x','y','width','height'))
        # Exclude a one-pixel compositor sampling edge around the actual buffer.
        delta.paste((0,0,0),(max(0,x-1),max(0,y-1),x+w+1,y+h+1))
        proof['outside'][name]={'changedBounds':delta.getbbox(),'samplingTolerance':1}
        assert delta.getbbox() is None,('Desktop changed outside bounded launcher',name,delta.getbbox())
        visual=ImageChops.difference(base,frame)
        regions=[data['input'],data['results']] if data['style']=='detached' and data['resultsVisible'] else [data['input']] if data['style']=='detached' else [data.get('surface',data['window'])]
        for region in regions:
            rx,ry,rw,rh=(int(region[key]) for key in ('x','y','width','height'))
            visual.paste((0,0,0),(max(0,rx-1),max(0,ry-1),rx+rw+1,ry+rh+1))
        proof['outsideVisualSurfaces'][name]={'changedBounds':visual.getbbox(),'samplingTolerance':1}
        assert visual.getbbox() is None,('Reserved canvas has a fill/blur outside visible surfaces',name,visual.getbbox())
        if data['style']=='detached' and data['resultsVisible']:
            a,b=data['input'],data['results']
            gap=(int(max(a['x'],b['x']))+24,int(a['y']+a['height'])+1,
                 int(min(a['x']+a['width'],b['x']+b['width']))-24,int(b['y'])-1)
            if gap[3]>gap[1]:
                difference=ImageChops.difference(base.crop(gap),frame.crop(gap))
                proof['detachedGap'][name]={'region':gap,'changedBounds':difference.getbbox()}
                assert difference.getbbox() is None,('Detached gap has fill/blur',name)
    if 'spotlight-empty' in by_name:
        rect=by_name['spotlight-empty']['input']
        box=(int(rect['x']+rect['width']-140),int(rect['y']+18),int(rect['x']+rect['width']-80),int(rect['y']+48))
        for name in ('spotlight-empty','spotlight-blur-control'):
            with Image.open(output/(name+'.png')) as frame:
                proof['nativeBlur'][name]=ImageStat.Stat(frame.crop(box).convert('L')).stddev[0]
        proof['nativeBlur']['region']=box
        proof['nativeBlur']['verified']=bool(blur_available)
        if blur_available:
            assert proof['nativeBlur']['spotlight-empty']<proof['nativeBlur']['spotlight-blur-control'],'Native blur did not soften details'
    (output/'pixel-proof.json').write_text(json.dumps(proof,indent=2)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true',required=True)
    parser.add_argument('--output',type=Path,default=Path('/tmp/rusticq-launcher-studio-native'))
    parser.add_argument('--source',type=Path,default=ROOT,help='Source snapshot to render for before/after comparisons')
    parser.add_argument('--styles',default=','.join(STYLES))
    parser.add_argument('--input',action='store_true',help='Type one safe character and Escape through wtype into the verified focused test window')
    options=parser.parse_args()
    styles=options.styles.split(',');assert all(style in STYLES for style in styles)
    assert os.environ.get('WAYLAND_DISPLAY'),'Wayland required'
    options.output.mkdir(parents=True,exist_ok=True)
    spec=importlib.util.spec_from_file_location('studio_blur',options.source/'scripts/rusticq-glass.py')
    backend=importlib.util.module_from_spec(spec);spec.loader.exec_module(backend)
    caps=backend.capabilities();assert caps.get('supported'),'Audited Hyprland Lua required for native blur verification'
    owner='studio-validation-'+str(os.getpid())
    prefix='rusticq-studio-test-'+str(os.getpid())+'-'
    lua_prefix='_G.__rusticq_studio_test_'+str(os.getpid())
    def scoped(enabled,backdrop=False,cleanup=False):
        program=backend.program(enabled,owner,cleanup,True,not backdrop,backdrop)
        return program.replace('rusticq-',prefix).replace('_G.__rusticq_rage',lua_prefix).replace(json.dumps(backend.TITLES,ensure_ascii=False),json.dumps('^RusticQ Studio Validation$'))
    global_before={key:backend.run(['hyprctl','-j','getoption',key]) for key in ['decoration:blur:enabled','decoration:blur:size','decoration:blur:passes']}
    process=None;captures=[]
    try:
        assert backend.run(['hyprctl','eval',scoped(True)])=='ok'
        with tempfile.TemporaryDirectory(prefix='rusticq-studio-native-') as folder:
            root=Path(folder)
            for name in ['config','components','modules','services','scripts','assets']:
                shutil.copytree(options.source/name,root/name,ignore=shutil.ignore_patterns('__pycache__'))
            overlay=root/'modules/main/LauncherOverlay.qml'
            overlay.write_text(overlay.read_text().replace('"rusticq-launcher"','"'+prefix+'launcher"').replace('"rusticq-launcher-backdrop"','"'+prefix+'launcher-backdrop"'))
            dock_path=root/'modules/main/RusticDock.qml'
            dock_path.write_text(dock_path.read_text().replace('"rusticq-dock"','"'+prefix+'dock"'))
            (root/'user-settings.json').write_text('{}');(root/'app-usage.json').write_text('{}')
            (root/'shell.qml').write_text(QML.replace('TEST_PREFIX',prefix))
            home=root/'home';home.mkdir()
            env=dict(os.environ,HOME=str(home),QT_QPA_PLATFORM='wayland',QT_QPA_PLATFORMTHEME='generic',XDG_STATE_HOME=str(root/'state'),XDG_CACHE_HOME=str(root/'cache'))
            log_path=options.output/'runtime.log'
            with log_path.open('w') as log:
                process=subprocess.Popen(['qs','-p',str(root),'--no-color'],env=env,stdout=log,stderr=subprocess.STDOUT)
                def ipc(method,*args):
                    response=subprocess.run(['qs','ipc','-p',str(root),'call','studio-validation',method,*args],capture_output=True,text=True,timeout=5)
                    if response.returncode:raise RuntimeError(response.stderr or response.stdout)
                    return response.stdout.strip()
                for attempt in range(60):
                    if process.poll() is not None:raise RuntimeError(log_path.read_text())
                    try:
                        if json.loads(ipc('metrics'))['apps']>0:break
                    except (RuntimeError,ValueError):pass
                    time.sleep(.1)
                time.sleep(.8)
                initial=json.loads(ipc('metrics'))
                controller_id,editor_id=initial['controller'],initial['editor']
                def capture(name, crop=None):
                    data=json.loads(ipc('metrics'))
                    assert data['controller']==controller_id and data['editor']==editor_id,'Style recreated controller or input'
                    subprocess.run(['grim','-o',data['screen'],str(options.output/(name+'.png'))],check=True,timeout=8)
                    if crop:
                        from PIL import Image
                        path=options.output/(name+'.png')
                        with Image.open(path) as original:
                            original.crop(crop).save(path)
                        data['crop']=list(crop)
                    captures.append(dict(name=name,**data));return data
                ipc('close');time.sleep(.4);capture('closed')
                for style in styles:
                    for state,query in [('empty',''),('populated','a')]:
                        mode='blur' if style=='launchpad' else 'dim-blur' if style=='overview' else 'dim' if style in ('compact','clean-hover') else 'none'
                        wants_blur=mode in ('blur','dim-blur')
                        assert backend.run(['hyprctl','eval',scoped(True,wants_blur)])=='ok'
                        ipc('blur','true' if caps.get('globalBlur') else 'false','true' if wants_blur and caps.get('globalBlur') else 'false')
                        assert ipc('frame',style,query,'auto')=='true'
                        time.sleep(.6)
                        data=capture(style+'-'+state)
                        assert data['logicalVisible'],'Capture interrupted by an outside click'
                        if state=='populated':assert data['count']>0,'Application search produced no results'
                        if style in ('spotlight','command','detached') and state=='empty':assert not data['resultsVisible']
                        if style in ('launchpad','overview'):
                            assert data['gridWidth']>data['window']['width']*.5,'Grid lost its usable width'
                if 'overview' in styles:
                    ipc('shortcuts','true');ipc('frame','overview','','auto')
                    time.sleep(.6);capture('overview-shortcuts');ipc('shortcuts','false')
                if 'detached' in styles:
                    backend.run(['hyprctl','eval',scoped(True)])
                    ipc('blur','true' if caps.get('globalBlur') else 'false','false')
                    ipc('frame','detached','a','none');time.sleep(.4)
                    for name,query in [('detached-one','Aether'),('detached-calculator','=sqrt(144)+8'),('detached-none','no-such-application-zzzzz'),('detached-cleared','')]:
                        ipc('query',query);time.sleep(.6);capture(name)
                    ipc('query','a');ipc('option','detachedLauncherInputInheritMaterial','false');ipc('option','detachedLauncherResultsInheritMaterial','false')
                    ipc('option','detachedLauncherInputOpacity','0.35');ipc('option','detachedLauncherResultsOpacity','0.65');time.sleep(.4);capture('detached-independent-materials')
                    ipc('option','detachedLauncherResultMode','"list"');time.sleep(.4);capture('detached-list')
                    ipc('option','detachedLauncherInputBackgroundEnabled','false');ipc('option','detachedLauncherInputOutlineEnabled','false')
                    ipc('option','detachedLauncherResultsBackgroundEnabled','false');ipc('option','detachedLauncherResultsOutlineEnabled','false')
                    time.sleep(.5);capture('detached-naked')
                for mode in ['none','dim','blur','dim-blur','focus']:
                    wants_blur=mode in ('blur','dim-blur')
                    assert backend.run(['hyprctl','eval',scoped(True,wants_blur)])=='ok'
                    ipc('blur','true' if caps.get('globalBlur') else 'false','true' if wants_blur and caps.get('globalBlur') else 'false')
                    ipc('frame','spotlight','',''+mode);time.sleep(.5);capture('backdrop-'+mode)
                # Compare the same alpha-aware surfaces with native blur disabled.
                backend.run(['hyprctl','eval',scoped(False)])
                ipc('frame','spotlight','','none');ipc('blur','true' if caps.get('globalBlur') else 'false','false');time.sleep(.5);capture('spotlight-blur-control')
                backend.run(['hyprctl','eval',scoped(True)])
                ipc('close');time.sleep(.3)
                for expanded,name in [(False,'dock-collapsed'),(True,'dock-expanded'),(False,'dock-closed-again')]:
                    ipc('showDock','true' if expanded else 'false');time.sleep(.4);capture(name)
                ipc('hideDock');time.sleep(.3)
                ipc('close');ipc('appBackground','true');time.sleep(.6)
                clients=json.loads(backend.run(['hyprctl','-j','clients']))
                app=next(client for client in clients if client.get('title')=='RusticQ Studio Validation' and client.get('pid')==process.pid)
                # Keep only the known fixture application interior, never unrelated
                # personal windows around it. Coordinates remain in captures.json.
                ax,ay=app['at'];aw,ah=app['size'];crop=(ax+8,ay+8,ax+aw-8,ay+ah-8)
                capture('application-closed',crop)
                ipc('frame','spotlight','a','none');time.sleep(.6);capture('spotlight-application',crop)
                ipc('close');ipc('appBackground','false');time.sleep(.4)
                if options.input:
                    assert shutil.which('wtype'),'wtype required for --input'
                    backend.run(['hyprctl','eval',scoped(True)])
                    ipc('frame','spotlight','','none');ipc('blur','true' if caps.get('globalBlur') else 'false','false');time.sleep(.4)
                    data=json.loads(ipc('metrics'))
                    assert data['nativeFocus'] and data['editorFocus'],'Refusing to inject keys into an unfocused window'
                    subprocess.run(['wtype','a'],env=env,check=True,timeout=5);time.sleep(.3)
                    assert json.loads(ipc('metrics'))['query']=='a','Native typing did not reach search'
                    subprocess.run(['wtype','-k','Escape'],env=env,check=True,timeout=5);time.sleep(.4)
                    assert not json.loads(ipc('metrics'))['logicalVisible'],'Escape did not close launcher'
                    capture('dismissed')
                process.terminate();process.wait(timeout=5);process=None
            output=log_path.read_text()
            for marker in ['TypeError:','ReferenceError:','Binding loop','Error loading configuration','Unable to assign']:
                assert marker not in output,output
        (options.output/'captures.json').write_text(json.dumps(dict(capabilities=caps,captures=captures),indent=2)+'\n')
        pixel_proof(options.output,captures,caps.get('globalBlur',False))
        print('PASS: native captures',len(captures),'single controller/input, output:',options.output)
    finally:
        if process is not None and process.poll() is None:
            process.terminate();process.wait(timeout=5)
        assert backend.run(['hyprctl','eval',scoped(False,cleanup=True)])=='ok'
        for key,value in global_before.items():assert value==backend.run(['hyprctl','-j','getoption',key]),'Global blur changed'


if __name__=='__main__':
    main()
