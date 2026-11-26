#!/usr/bin/env python3
"""Capture real Wayland materials over a temporary detailed test application.

Explicit --run: briefly covers the desktop, without changing its wallpaper,
settings, global blur or persistent compositor rules. Input/data are fixtures.
The validation rule matches ONLY the fixture's unique layer namespaces.
"""
import argparse
import ast
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
QML = r'''import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "config"
import "components"
import "services"
import "modules/main"
import "modules/bar"
import "modules/settings"
ShellRoot {
    id:suite
    property int phase:0
    property var patterns:["monochrome","white","color","grid","text"]
    property string pattern:patterns[phase] || "grid"
    onPatternChanged: {
        if (pattern === "settings") Store.settingsTab="appearance";
        popup.kind=phase<5 ? "wifi" : "";
        for(const key of ["desktopClock","desktopCalendar","desktopSystem","desktopWeather","desktopMedia","desktopNotes","desktopKanban"]) SettingsStore[key]=phase<5;
        Store.settingsVisible=pattern==="settings";
        Store.sidebarVisible=pattern==="quick-control";
        Store.launcherVisible=pattern==="launcher";
    }
    PanelWindow {
        id:backdrop;screen:Quickshell.screens[0]
        WlrLayershell.namespace:"TEST_PREFIXbackground"
        WlrLayershell.layer:WlrLayer.Top
        WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
        exclusionMode:ExclusionMode.Ignore
        anchors{top:true;bottom:true;left:true;right:true}
        mask:Region {}
        // Keep test patterns above normal applications, even if a CLI approval
        // changes focus. The normal Settings window needs the layer released.
        visible:suite.pattern!=="settings";color:"#ffffff"
        Canvas {
            id:canvas;anchors.fill:parent
            onPaint:{
                const c=getContext("2d"), w=width, h=height;
                c.fillStyle=suite.pattern==="white"?"#ffffff":"#16171c";c.fillRect(0,0,w,h);
                if(["grid","settings","quick-control","launcher"].indexOf(suite.pattern)>=0) {
                    for(let y=0;y<h;y+=12) for(let x=0;x<w;x+=12) {c.fillStyle=((x/12+y/12)%2)?"#eeeeee":"#202127";c.fillRect(x,y,12,12);}
                } else if(suite.pattern==="color") {
                    const colors=["#225aa5","#60a885","#be7462","#9559a5","#dfb967"];
                    for(let x=0;x<w;x+=80) {c.fillStyle=colors[Math.floor(x/80)%5];c.fillRect(x,0,80,h);}
                    c.strokeStyle="#e7e7ed";c.lineWidth=2;
                    for(let y=0;y<h;y+=24){c.beginPath();c.moveTo(0,y);c.lineTo(w,y+100);c.stroke();}
                } else if(suite.pattern==="monochrome") {
                    c.strokeStyle="#a0a0a7";c.lineWidth=2;
                    for(let x=-h;x<w;x+=22){c.beginPath();c.moveTo(x,0);c.lineTo(x+h,h);c.stroke();}
                    c.fillStyle="#d0d0d7";for(let x=0;x<w;x+=110)c.fillRect(x,0,26,h);
                } else if(suite.pattern==="text") {
                    c.fillStyle="#fafafa";c.fillRect(0,0,w,h);c.fillStyle="#16171c";c.font="14px monospace";
                    for(let y=16;y<h;y+=22)c.fillText("Background application: sharp source text 0123456789 · Native blur should soften this text behind glass. ".repeat(4),8,y);
                }
            }
        }
        Connections {target:suite;function onPatternChanged(){canvas.requestPaint();}}
    }
    Bar { id:bar;screen:backdrop.screen;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXbar" }
    DesktopWidgetWindow {kind:"clock";screen:backdrop.screen;previewX:32;previewY:86;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXclock"}
    DesktopWidgetWindow {kind:"calendar";screen:backdrop.screen;previewX:32;previewY:265;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXcalendar"}
    DesktopWidgetWindow {kind:"system";screen:backdrop.screen;previewX:366;previewY:86;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXsystem"}
    DesktopWidgetWindow {kind:"weather";screen:backdrop.screen;previewX:366;previewY:430;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXweather"}
    DesktopWidgetWindow {kind:"media";screen:backdrop.screen;previewX:700;previewY:86;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXmedia"}
    DesktopWidgetWindow {kind:"notes";screen:backdrop.screen;previewX:700;previewY:360;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXnotes"}
    DesktopWidgetWindow {kind:"kanban";screen:backdrop.screen;previewX:1045;previewY:550;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXkanban"}
    IndicatorPopup {id:popup;hostWindow:bar;kind:"wifi";targetX:1480;barPosition:"top";WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXpopup";onDismissed:kind=""}
    RusticDock {screen:backdrop.screen;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXdock"}
    SettingsWindow {id:settings;title:"RAGE material validation settings";screen:backdrop.screen}
    MotionLoader {shown:Store.sidebarVisible;BarWrapper {screen:backdrop.screen;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXquick"}}
    MotionLoader {shown:Store.launcherVisible;LauncherOverlay {screen:backdrop.screen;WlrLayershell.namespace:"TEST_PREFIXlauncher"}}
    PanelWindow {
        screen:backdrop.screen
        anchors{left:true;bottom:true}
        margins{left:32;bottom:25}
        implicitWidth:850;implicitHeight:38;color:"#15151b";exclusionMode:ExclusionMode.Ignore
        WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:"TEST_PREFIXlabel"
        Text {anchors.centerIn:parent;text:"RAGE · CAPTURE_TAG · "+suite.pattern+" · real Wayland / compositor blur · fixture data";color:"white";font.pixelSize:15}
    }
    Process {
        id:capture
        command:["grim","-o",backdrop.screen.name,Quickshell.env("RAGE_CAPTURE_OUTPUT")+"/"+suite.pattern+".png"]
        onExited:(code,status)=>{
            if(code!==0) {console.log("CAPTURE FAILED");Qt.quit();return;}
            console.log("CAPTURED",suite.pattern);
            if(suite.phase>=suite.patterns.length-1){Qt.quit();return;}
            suite.phase++;settle.restart();
        }
    }
    Timer {id:settle;interval:1000;onTriggered:capture.running=true}
    Timer {interval:25000;running:true;onTriggered:Qt.quit()}
    Component.onCompleted:{
        SettingsStore.animationsEnabled=false;SettingsStore.glassmorphismEnabled=true;
        SettingsStore.glassOpacity=.44;SettingsStore.glassBorderOpacity=.16;SettingsStore.glassShadowIntensity=.14;
        SettingsStore.barMode="separated";SettingsStore.showDock=true;SettingsStore.dockAutoHide=false;SettingsStore.dockRunningApps=false;
        SettingsStore.desktopClock=true;SettingsStore.desktopCalendar=true;SettingsStore.desktopSystem=true;
        SettingsStore.desktopWeather=true;SettingsStore.desktopMedia=true;SettingsStore.desktopNotes=true;SettingsStore.desktopKanban=true;
        Store.glassBlurActive=BLUR_ACTIVE;
        NATIVE_PROVIDER
        settle.restart();
    }
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run',action='store_true',required=True)
    parser.add_argument('--source',type=Path,default=ROOT)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--tag',default='after')
    parser.add_argument('--disable-blur',action='store_true',help='Keep material alpha unchanged; disable only the fixture rule to compare real blur')
    parser.add_argument('--only-grid',action='store_true')
    parser.add_argument('--panels',action='store_true',help='Also capture Settings, Quick Control and Launcher')
    options=parser.parse_args()
    assert os.environ.get('WAYLAND_DISPLAY'), 'Wayland required'
    options.output.mkdir(parents=True,exist_ok=True)
    prefix=f'rusticq-material-test-{os.getpid()}-'
    rule=f'rusticq-material-validation-{os.getpid()}'
    window_rule=rule+'-window'
    spec=importlib.util.spec_from_file_location('rage_capture_backend',options.source/'scripts/rusticq-glass.py')
    backend=importlib.util.module_from_spec(spec);spec.loader.exec_module(backend)
    capabilities=backend.capabilities()
    assert capabilities.get('supported'), 'An audited Hyprland Lua backend is required for native captures'
    (options.output/'capabilities.json').write_text(json.dumps(capabilities,indent=2)+'\n')
    before=backend.run(['hyprctl','-j','getoption','decoration:blur:enabled'])
    try:
        program='hl.layer_rule({name='+json.dumps(rule)+',match={namespace='+json.dumps('^'+prefix+'.*$')+'},blur='+('false' if options.disable_blur else 'true')+',ignore_alpha=0.02,xray=false})'
        assert backend.run(['hyprctl','eval',program])=='ok'
        assert backend.run(['hyprctl','eval','hl.window_rule({name='+json.dumps(window_rule)+',match={class="^org[.]quickshell$",title="^RAGE material validation settings$"},float=true,center=true,no_blur=false})'])=='ok'
        with tempfile.TemporaryDirectory(prefix='rage-material-capture-') as folder:
            root=Path(folder)
            for directory in ['config','components','modules','services','scripts','assets']:
                shutil.copytree(options.source/directory,root/directory,ignore=shutil.ignore_patterns('__pycache__'))
            (root/'user-settings.json').write_text('{}')
            (root/'app-usage.json').write_text('{}')
            # Do not capture users' actual SSIDs, media titles, weather location or notes.
            (root/'fixtures').mkdir()
            (root/'fixtures/qmldir').write_text('singleton WifiFixture 1.0 WifiFixture.qml\nsingleton Mpris 1.0 Mpris.qml\n')
            (root/'fixtures/Mpris.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property QtObject players:QtObject {property var values:[{isPlaying:true,identity:"Player",trackTitle:"Glass study",trackArtist:"Demo artist",canControl:false}]}}''')
            widget=root/'modules/main/DesktopWidgetWindow.qml'
            widget.write_text(widget.read_text().replace('import Quickshell.Services.Mpris','import "../../fixtures"'))
            (root/'fixtures/WifiFixture.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell.Networking
QtObject {
    property QtObject studio:QtObject {signal connectionFailed(int reason);property string name:"Studio Network";property string ssid:name;property real signalStrength:.95;property bool connected:true;property bool known:true;property int security:WifiSecurityType.Wpa2Psk;property int connectionState:2}
    property QtObject lounge:QtObject {signal connectionFailed(int reason);property string name:"Public Lounge";property string ssid:name;property real signalStrength:.72;property bool connected:false;property bool known:false;property int security:WifiSecurityType.Open;property int connectionState:0}
    property QtObject guest:QtObject {signal connectionFailed(int reason);property string name:"Guest Network";property string ssid:name;property real signalStrength:.55;property bool connected:false;property bool known:true;property int security:WifiSecurityType.Wpa2Psk;property int connectionState:0}
    property QtObject device:QtObject {property string name:"wlan0";property QtObject networks:QtObject {property var values:[studio,lounge,guest]}}
}''')
            tests=(ROOT/'tools/test_wifi_audio_ui.py').read_text()
            for filename in ['WifiManager','WifiService']:
                match=re.search(r"\(target / 'services/"+filename+r".qml'\).write_text\('''(.*?)'''\)",tests,re.S)
                assert match,filename
                # Decode the Python fixture literal once, exactly as the UI test does.
                (root/'services'/f'{filename}.qml').write_text(ast.literal_eval("'''"+match[1]+"'''"))
            wifi=root/'services/WifiService.qml'
            wifi.write_text(wifi.read_text().replace('property bool enabled: true', 'property string icon:"\\ue63e"\n    property bool connected:true\n    property string ssid:"Studio Network"\n    property int strength:95\n    property bool ethernetConnected:false\n    property string ethernetName:""\n    property int ethernetMbps:0\n    property bool enabled: true'))
            (root/'services/NotificationCenter.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property var history:[];property var displayHistory:[];property var toast:null;property bool doNotDisturb:false;property int unread:0;property bool groupByApp:false;property bool receivesSystemNotifications:true;property string serverOwner:"Fixture";property string serverAdvice:"";function markRead(){}
function refreshServerStatus(){}}''')
            for metadata in ['version.json','release.json']:
                if (options.source/metadata).is_file():shutil.copy2(options.source/metadata,root/metadata)
            (root/'services/WeatherService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property string temperature:"24°C";property string feelsLike:"25°C";property string location:"Example City";property string condition:"Partly cloudy";property string icon:"\\uf172";property bool loading:false;property string lastError:"";property double lastUpdated:Date.now();function refresh(){}}''')
            native='SettingsStore.rageMode="exclusive";SettingsStore.ragePalette="obsidian";' if 'property string rageMode:' in (root/'config/SettingsStore.qml').read_text() else ''
            source=QML.replace('TEST_PREFIX',prefix).replace('CAPTURE_TAG',options.tag).replace('BLUR_ACTIVE',json.dumps(capabilities.get('globalBlur',False))).replace('NATIVE_PROVIDER',native)
            if options.only_grid:
                source=source.replace('["monochrome","white","color","grid","text"]','["grid"]')
            elif options.panels:
                source=source.replace('["monochrome","white","color","grid","text"]','["monochrome","white","color","grid","text","settings","quick-control","launcher"]')
            (root/'shell.qml').write_text(source)
            env=dict(os.environ,QT_QPA_PLATFORM='wayland',QT_QPA_PLATFORMTHEME='generic',RAGE_CAPTURE_OUTPUT=str(options.output.resolve()),
                     XDG_STATE_HOME=str(root/'state'),XDG_CACHE_HOME=str(root/'cache'))
            result=subprocess.run(['qs','-p',str(root/'shell.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=35)
            output=result.stdout+result.stderr
            (options.output/'runtime.log').write_text(output)
            assert result.returncode==0 and output.count('CAPTURED')==(1 if options.only_grid else 8 if options.panels else 5),output
            assert not re.search(r'(TypeError:|ReferenceError:|Binding loop|Error loading configuration)',output),output
            (options.output/'layers.json').write_text(backend.run(['hyprctl','-j','layers']))
        print('Captured compositor screenshots:',options.output)
    finally:
        backend.run(['hyprctl','eval','hl.layer_rule({name='+json.dumps(rule)+',enabled=false})'])
        backend.run(['hyprctl','eval','hl.window_rule({name='+json.dumps(window_rule)+',enabled=false})'])
        assert before==backend.run(['hyprctl','-j','getoption','decoration:blur:enabled'])


if __name__=='__main__':
    main()
