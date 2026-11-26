#!/usr/bin/env python3
"""Production modular controls with offline devices, isolated preferences and Qt Quick.

No real network, power, backlight, monitor configuration or audio is changed.
"""
import argparse
import json
import os
from pathlib import Path
import re
import sys
import subprocess
import tempfile
from test_clock_ui import run_qml
from test_glassmorphism_ui import fixture

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "config"
import "components"
import "services"
import "fixtures" as Fixtures
import "modules/bar"
import "modules/quickcontrol"
import "modules/settings/pages"
ShellRoot {
    Window {
        id:window
        visible:true;width:940;height:1040;color:"transparent"
        Item {id:preview;width:400;height:980
            Column {anchors.fill:parent;spacing:8
                BarHeader {width:parent.width;height:42}
                QuickControlCards {id:cards;width:parent.width;height:910}
            }
        }
        BarSystem {id:standaloneSystem;visible:false;compactQuick:true;width:368;height:compactHeight}
        BarNotifications {id:standaloneNotes;visible:false;width:368;height:600}
        ApplicationAudioMixer {id:standaloneMixer;visible:false;width:350}
        QuickControlSettings {id:editor;visible:false;x:440;width:470}
        QuickControlInputMask {id:inputMask;windowItem:window.contentItem}
        QtObject {id:sink;property QtObject audio:QtObject {property real volume:1.5;property bool muted:false;property var channels:[1,2]}
            property bool isSink:true;property bool isStream:false;property bool ready:true;property string description:"Ryzen HD Audio Controller";property string name:"speakers";property string nickname:"Speakers"}
        QtObject {id:mic;property QtObject audio:QtObject {property real volume:.86;property bool muted:false;property var channels:[1,2]}
            property bool isSink:false;property bool isStream:false;property bool ready:true;property string description:"Available microphone";property string name:"mic";property string nickname:"Mic"}
        QtObject {id:stream;property QtObject audio:QtObject {property real volume:1.5;property bool muted:false;property var channels:[1,2]}
            property bool isSink:true;property bool isStream:true;property bool ready:true;property string description:"Virtual Source";property string name:"virtual";property string nickname:"Virtual Source"
            property var properties:({"application.name":"Virtual Source","media.name":"Virtual Source output"})}
        QtObject {id:player;property bool isPlaying:true;property string identity:"Fixture player";property string trackTitle:"A track title with a long name";property string trackArtist:"Artist";property string trackArtUrl:""
            property bool canTogglePlaying:true;property bool canGoPrevious:true;property bool canGoNext:true;property bool canSeek:true;property bool positionSupported:true;property bool lengthSupported:true
            property real position:30;property real length:180;property int previousCalls:0;property int nextCalls:0
            function togglePlaying(){isPlaying=!isPlaying;} function previous(){previousCalls++;}function next(){nextCalls++;}}
        TestCase {
            name:"FramelessQuickControl"
            when:true
            property string checkpoint:""
            function modular(){return findChild(cards,"modularQuickControl");}
            function init(){
                SettingsStore.animationsEnabled=false;
                SettingsStore.applyQuickControlSettings(SettingsStore.quickControlDefaults);
                SettingsStore.quickControlLayout="frameless";
                Store.sidebarVisible=true;Store.advancedVisible=false;Store.quickReorderMode=false;
                SettingsStore.quickControlOrder=SettingsStore.defaultQuickOrder.slice();
                Fixtures.Pipewire.defaultAudioSink=sink;Fixtures.Pipewire.defaultAudioSource=mic;
                Fixtures.Pipewire.nodes.values=[sink,mic,stream];Fixtures.Mpris.players.values=[player];
                sink.audio.volume=1.5;sink.audio.muted=false;stream.audio.volume=1.5;stream.audio.muted=false;
                preview.width=400;cards.height=910;checkpoint="";wait(100);
                Fixtures.NetworkFixture.wifiEnabled=true;Fixtures.NetworkFixture.wifiHardwareEnabled=true;
                BluetoothService.adapter=BluetoothService.availableAdapter;BluetoothService.adapter.enabled=true;
            }
            function cleanup(){console.log("QUICK CONTROL TEST",qtest_results.functionName,"failed",qtest_results.failed,"checkpoint",checkpoint);}
            function cleanupTestCase(){console.log("QUICK CONTROL RESULTS",qtest_results.passCount,"passed,",qtest_results.failCount,"failed");}
            function capture(name){const folder=Quickshell.env("RUSTICQ_QUICK_CAPTURE");if(folder){waitForRendering(preview);grabImage(preview).save(folder+"/"+name+".png");}}
            function test_a_classic_modular_frameless_and_scope(){
                compare(SettingsStore.quickControlDefaults.quickControlLayout,"classic");
                verify(QuickControlStyle.frameless);compare(QuickControlStyle.panelBackground,false);compare(QuickControlStyle.panelOutline,false);
                SettingsStore.quickControlPanelBackground=true;SettingsStore.quickControlPanelOutline=true;
                compare(QuickControlStyle.panelBackground,false);compare(QuickControlStyle.panelOutline,false);
                SettingsStore.quickControlLayout="modular";verify(QuickControlStyle.panelBackground && QuickControlStyle.panelOutline);
                checkpoint="classic";SettingsStore.quickControlLayout="classic";tryVerify(()=>modular()===null);verify(QuickControlStyle.panelBackground);
                compare(standaloneSystem.framelessQuickControl,false);compare(standaloneNotes.framelessQuickControl,false);compare(standaloneMixer.framelessQuickControl,false);
                SettingsStore.quickControlLayout="frameless";tryVerify(()=>modular()!==null);
                const system=findChild(modular(),"quickModule_system");
                checkpoint="four metric columns";
                compare(findChild(system,"quickMetricsGrid").columns,4);
                checkpoint="two metric columns";preview.width=300;wait(80);compare(findChild(system,"quickMetricsGrid").columns,2);
                preview.width=400;wait(80);capture("frameless-quick-control");
            }
            function test_b_surfaces_input_regions_and_settings(){
                const tile=findChild(modular(),"quickModule_wifi");
                const toggle=findChild(tile,"tileToggle");
                verify(toggle!==null);
                verify(Store.quickControlInputItems.indexOf(toggle)>=0);
                const rect=QuickControlStyle.hitRect(toggle,window.contentItem,0);
                verify(rect.width>0 && rect.height>0);
                const wifiRect=QuickControlStyle.hitRect(findChild(modular(),"quickWifiTile"),window.contentItem,0);
                const gapX=wifiRect.x+wifiRect.width+QuickControlStyle.gap/2,gapY=wifiRect.y+20;
                const snapshot=grabImage(preview);
                compare(snapshot.alpha(Math.floor(gapX),Math.floor(gapY)),0);
                for(const item of Store.quickControlInputItems){
                    const hit=QuickControlStyle.hitRect(item,window.contentItem,0);
                    verify(!(hit.width>0 && hit.height>0 && gapX>=hit.x && gapX<hit.x+hit.width && gapY>=hit.y && gapY<hit.y+hit.height),"transparent tile gap captured");
                }
                compare(QuickControlStyle.surface(false,false,false).a,SettingsStore.quickControlSurfaceOpacity);
                SettingsStore.quickControlComponentBackground=false;
                compare(QuickControlStyle.surface(false,false,false).a,0);
                verify(QuickControlStyle.surface(false,true,false).a>0);
                SettingsStore.quickControlComponentOutline=false;compare(toggle.border.width,0);
                SettingsStore.quickControlComponentOutline=true;compare(toggle.border.width,1);
                SettingsStore.quickControlAnimations=false;compare(QuickControlStyle.motion,false);
                for(const bad of [null,"12",true,NaN])verify(!SettingsStore.setQuickControlSetting("quickControlPanelWidth",bad,false));
                SettingsStore.setQuickControlSetting("quickControlPanelWidth",10000,false);compare(SettingsStore.quickControlPanelWidth,560);
                SettingsStore.setQuickControlSetting("quickControlSurfaceOpacity",-2,false);compare(SettingsStore.quickControlSurfaceOpacity,0);
            }
            function test_c_actual_two_dimensional_reorder_and_stable_delegates(){
                const main=modular(),wifi=findChild(main,"quickModule_wifi"),bluetooth=findChild(main,"quickModule_bluetooth");
                verify(bluetooth.x>wifi.x);fuzzyCompare(wifi.y,bluetooth.y,.5);
                const target=bluetooth.mapToItem(main.contentItem,bluetooth.width/2,bluetooth.height/2);
                compare(main.dragTarget(target.x,target.y),1);
                Store.quickReorderMode=true;wait(50);
                const grip=findChild(main,"quickGrip_wifi");grip.forceActiveFocus();keyClick(Qt.Key_Right);wait(60);
                compare(SettingsStore.quickControlOrder[1],"wifi");
                compare(findChild(main,"quickModule_wifi"),wifi);
                verify(wifi.x>bluetooth.x);
                verify(SettingsStore.validQuickOrder(SettingsStore.quickControlOrder));
                SettingsStore.moveQuickCard("battery",0);wait(50);
                compare(SettingsStore.quickControlOrder[0],"battery");
                const battery=findChild(main,"quickModule_battery");fuzzyCompare(battery.width,main.width,.5);
                SettingsStore.resetQuickOrder();wait(50);compare(SettingsStore.quickControlOrder.join(","),SettingsStore.defaultQuickOrder.join(","));
            }
            function test_b2_readable_control_materials_over_light_and_dark_backdrops(){
                function linear(value){return value<=.04045 ? value/12.92 : Math.pow((value+.055)/1.055,2.4);}
                function luminance(color){return .2126*linear(color.r)+.7152*linear(color.g)+.0722*linear(color.b);}
                function contrast(ink,surface,backdrop){
                    const background=Qt.rgba(surface.r*surface.a+backdrop.r*(1-surface.a),surface.g*surface.a+backdrop.g*(1-surface.a),surface.b*surface.a+backdrop.b*(1-surface.a),1);
                    const a=luminance(ink),b=luminance(background);
                    return (Math.max(a,b)+.05)/(Math.min(a,b)+.05);
                }
                SettingsStore.quickControlAccentTint=false;
                for(const palette of ["graphite-frost","pearl"]){
                    SettingsStore.rageMode="exclusive";SettingsStore.ragePalette=palette;
                    for(const glass of [false,true]){
                        SettingsStore.glassmorphismEnabled=glass;
                        const surface=QuickControlStyle.surface(false,false,false);
                        verify(surface.a>=.9,"control material too transparent");
                        for(const backdrop of [Qt.rgba(0,0,0,1),Qt.rgba(1,1,1,1)])
                            verify(contrast(Theme.foreground,surface,backdrop)>=4.5,"unreadable "+palette+" glass="+glass);
                        SettingsStore.quickControlHoverOpacity=.1;
                        verify(QuickControlStyle.surface(false,true,false).a>=surface.a,"hover faded control");
                        verify(QuickControlStyle.surface(false,false,true).a>=surface.a,"press faded control");
                    }
                }
                SettingsStore.rageMode="adaptive";SettingsStore.glassmorphismEnabled=false;
            }
            function test_c2_connectivity_toggle_and_full_width_detail_window(){
                const wifi=findChild(modular(),"quickWifiTile"),bluetooth=findChild(modular(),"quickBluetoothTile");
                mouseClick(findChild(wifi,"tileToggle"));compare(Fixtures.NetworkFixture.wifiEnabled,false);
                mouseClick(findChild(wifi,"tileToggle"));compare(Fixtures.NetworkFixture.wifiEnabled,true);
                Fixtures.NetworkFixture.wifiHardwareEnabled=false;compare(findChild(wifi,"tileToggle").enabled,false);
                mouseClick(findChild(bluetooth,"tileToggle"));compare(BluetoothService.enabled,false);
                Store.sidebarScreen=Quickshell.screens[0];
                wifi.detailsRequested();compare(Store.deviceSettingsKind,"wifi");compare(Store.deviceSettingsScreen,Store.sidebarScreen);
                compare(Store.deviceSettingsPending,true);compare(Store.sidebarVisible,false);
                Store.closeDeviceSettings();Store.sidebarVisible=true;
                BluetoothService.adapter=null;compare(findChild(bluetooth,"tileToggle").enabled,false);
            }
            function test_d_volume_amplification_mute_and_missing_devices(){
                const output=findChild(modular(),"quickOutputVolume");
                compare(output.value,1.5);compare(output.maximumValue,1.5);compare(sink.audio.volume,1.5);
                const track=findChild(output,"quickSliderTrack");track.forceActiveFocus();keyClick(Qt.Key_Left);fuzzyCompare(sink.audio.volume,1.48,.001);
                mouseClick(track,track.width*.5,track.height/2);fuzzyCompare(sink.audio.volume,.75,.02);
                output.iconClicked();compare(sink.audio.muted,true);
                Fixtures.Pipewire.defaultAudioSink=null;wait(30);compare(output.adjustable,false);
                output.userChanged(.8); // production guard also rejects stale signals
                compare(sink.audio.volume,.75);
                Fixtures.Pipewire.defaultAudioSink=sink;
                Store.advancedVisible=true;Store.quickAdvancedTab="audio";wait(100);
                const mixerSlider=findChild(cards,"modularStreamSlider");verify(mixerSlider!==null);
                compare(mixerSlider.value,1.5);compare(stream.audio.volume,1.5);
                mixerSlider.userChanged(1.35);compare(stream.audio.volume,1.35);
                stream.audio.volume=2.25;compare(mixerSlider.value,2.25);verify(mixerSlider.rangeMaximum>=2.25);
                mixerSlider.userChanged(1.35);verify(mixerSlider.rangeMaximum>=2.25);
                const micSlider=findChild(cards,"advancedSourceSlider");micSlider.userChanged(1.25);compare(mic.audio.volume,1.25);
                capture("frameless-audio");
            }
            function test_e_tabs_media_and_single_brightness_controller(){
                Store.advancedVisible=true;wait(80);
                checkpoint="tabs";
                for(const key of ["audio","display","media"]){mouseClick(findChild(cards,"advancedTab_"+key));compare(Store.quickAdvancedTab,key);wait(70);}
                const media=findChild(cards,"quickMediaSeek");
                checkpoint="media seek";
                verify(media!==null);media.userChanged(.5);compare(player.position,90);
                player.canSeek=false;wait(30);compare(findChild(cards,"quickMediaSeek"),null);
                player.canSeek=true;Fixtures.Mpris.players.values=[];wait(40);compare(findChild(cards,"quickMediaSeek"),null);
                Store.quickAdvancedTab="display";wait(60);
                checkpoint="brightness";
                const monitors=findChild(cards,"advancedMonitorControls");
                compare(findChild(monitors,"monitorPreview").visible,false);
                tryCompare(BrightnessService,"available",true);
                BrightnessService.setBrightness(.68);compare(BrightnessService.brightness,.68);
                BrightnessService.setBrightness(.69);BrightnessService.setBrightness(.7);wait(300);
                compare(BrightnessService.writing,false);compare(BrightnessService.pendingBrightness,70);
                capture("frameless-display");
            }
            function test_f_small_screen_optional_content_and_live_palettes(){
                const main=modular();cards.height=240;wait(60);verify(main.contentHeight>main.height);
                main.contentY=main.contentHeight-main.height;wait(30);verify(main.contentY>0);
                SettingsStore.showNotifications=false;wait(30);compare(findChild(main,"quickModule_notifications").visible,false);
                SettingsStore.showNotifications=true;
                for(const exclusive of [false,true]){
                    SettingsStore.glassmorphismEnabled=true;SettingsStore.rageMode=exclusive ? "exclusive" : "adaptive";
                    SettingsStore.quickControlAccentTint=true;
                    const material=QuickControlStyle.glass ? Theme.glassTint : Theme.surface;
                    const expected=Theme.mix(material,Theme.accent,.18);
                    const selected=QuickControlStyle.surface(true,false,false);
                    fuzzyCompare(selected.r,expected.r,.001);fuzzyCompare(selected.g,expected.g,.001);
                }
                SettingsStore.glassmorphismEnabled=false;
                cards.height=910;
            }
            function test_g_settings_controls_commit_and_restart(){
                editor.visible=true;wait(50);
                mouseClick(findChild(editor,"quickLayout_modular"));compare(SettingsStore.quickControlLayout,"modular");
                const range=findChild(editor,"quickControlPanelWidthSlider");
                const before=SettingsStore.settingsSnapshot;
                range.preview(448);compare(SettingsStore.quickControlPanelWidth,448);compare(SettingsStore.settingsSnapshot,before);
                range.commit(448);compare(JSON.parse(SettingsStore.settingsSnapshot).quickControlPanelWidth,448);
                SettingsStore.setQuickControlSetting("quickControlComponentRadius",18,true);
                SettingsStore.moveQuickCard("notifications",0);
                editor.visible=false;
            }
        }
    }
}
'''


def prepare(folder):
    root=fixture(folder)
    fixtures=root/'fixtures';fixtures.mkdir()
    (fixtures/'qmldir').write_text('singleton Pipewire 1.0 Pipewire.qml\nPwObjectTracker 1.0 PwObjectTracker.qml\nPwNodePeakMonitor 1.0 PwNodePeakMonitor.qml\nsingleton PwAudioChannel 1.0 PwAudioChannel.qml\nsingleton Mpris 1.0 Mpris.qml\nsingleton NetworkFixture 1.0 NetworkFixture.qml\n')
    (fixtures/'NetworkFixture.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property bool wifiEnabled:true;property bool wifiHardwareEnabled:true;property QtObject device:QtObject {property string name:"wlan0";property QtObject networks:QtObject {property var values:[]}}}
''')
    (root/'services/WifiManager.qml').write_text('''import QtQuick
import "../fixtures"
QtObject {property var wifiDevice:NetworkFixture.device;property bool wifiEnabled:NetworkFixture.wifiEnabled;property bool wifiHardwareEnabled:NetworkFixture.wifiHardwareEnabled;property bool scanning:false;property var processingNetwork:null
function toggleWifi(){NetworkFixture.wifiEnabled=!NetworkFixture.wifiEnabled;}function toggleScan(){}function signalIcon(value){return "\\ue63e";}function stateText(network){return "Available";}function clearProcessing(network){}function connectNetwork(network){}function disconnectNetwork(network){}function forgetNetwork(network){}function connectWithPassword(network,password){} }
''')
    (root/'services/BluetoothService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property QtObject availableAdapter:QtObject {property bool enabled:true};property var adapter:availableAdapter;readonly property bool enabled:adapter!==null && adapter.enabled;property bool connected:false;property string deviceName:"";property string icon:"\\ue1a7"}
''')
    (fixtures/'Pipewire.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property QtObject nodes:QtObject {property var values:[]};property var defaultAudioSink:null;property var defaultAudioSource:null;property var preferredDefaultAudioSink:null;property var preferredDefaultAudioSource:null}
''')
    (fixtures/'PwObjectTracker.qml').write_text('import QtQuick\nQtObject {property var objects:[]}\n')
    (fixtures/'PwNodePeakMonitor.qml').write_text('import QtQuick\nQtObject {property var node;property bool enabled:true;property real peak:.38}\n')
    (fixtures/'PwAudioChannel.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {enum Channel {Unknown}}\n')
    (fixtures/'Mpris.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject {property QtObject players:QtObject {property var values:[]}}\n')
    for name,relative in [('modules/bar/BarAdvanced.qml','../../fixtures'),('modules/quickcontrol/ModularQuickControl.qml','../../fixtures'),('modules/quickcontrol/QuickControlMedia.qml','../../fixtures'),('components/ApplicationAudioMixer.qml','../fixtures')]:
        path=root/name
        path.write_text(path.read_text().replace('import Quickshell.Services.Pipewire',f'import "{relative}"').replace('import Quickshell.Services.Mpris',f'import "{relative}"'))
    (root/'services/QuickModesService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property bool busy:false;property string error:"";property var toggles:({awake:false,silent:false,night:false,gaming:false});function active(key){return !!toggles[key];}function available(key){return true;}function detail(key){return key;}function toggle(key){const next=Object.assign({},toggles);next[key]=!next[key];toggles=next;}function refresh(){}function setNightLightTemperature(value){} }
''')
    (root/'services/SysMonService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property real cpuUsage:8;property real memUsedGB:5.2;property real memTotalGB:16;property real memUsedPercent:.325;property real diskUsedGB:60;property real diskTotalGB:255;property real diskAvailableGB:195;property real diskUsedPercent:.235;property real temperature:61}
''')
    (root/'scripts/rusticq-audio-peak.py').write_text('import time\nprint(".3",flush=True)\ntime.sleep(5)\n')
    (root/'scripts/rustiq-display.py').write_text('print(\'{"ok":true,"monitors":[]}\')\n')
    (root/'bin').mkdir()
    (root/'backlight').write_text('50')
    brightness=root/'bin/brightnessctl'
    brightness.write_text('#!'+sys.executable+'\nimport sys\nfrom pathlib import Path\np=Path(__file__).parents[1]/"backlight"\nif "set" in sys.argv:p.write_text(sys.argv[-1].rstrip("%"))\nelse:print("fixture,backlight,50,"+p.read_text()+"%,100")\n')
    brightness.chmod(0o700)
    hyprctl=root/'bin/hyprctl'
    hyprctl.write_text('#!'+sys.executable+'\nprint("[]")\n')
    hyprctl.chmod(0o700)
    return root


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--capture-dir',default='')
    args=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='rusticq-quick-control-ui-') as folder:
        root=prepare(folder)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder,
                 XDG_STATE_HOME=str(root/'state'),XDG_CACHE_HOME=str(root/'cache'),PATH=str(root/'bin')+os.pathsep+os.environ['PATH'])
        if args.capture_dir:
            captures=Path(args.capture_dir).resolve();captures.mkdir(parents=True,exist_ok=True);env['RUSTICQ_QUICK_CAPTURE']=str(captures)
        try:
            output=run_qml(root,env,QML)
        except subprocess.TimeoutExpired as error:
            print((error.stdout or b'').decode(errors='replace'))
            print((error.stderr or b'').decode(errors='replace'))
            raise
        summary=re.search(r'QUICK CONTROL RESULTS (\d+) passed, (\d+) failed',output)
        assert summary and int(summary[1])>=10 and int(summary[2])==0,output
        saved=json.loads((root/'user-settings.json').read_text())
        assert saved['quickControlLayout']=='modular' and saved['quickControlPanelWidth']==448 and saved['quickControlComponentRadius']==18
        assert saved['quickControlOrder'][0]=='notifications'
        reload='''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {TestCase {when:true;function test_reload(){compare(SettingsStore.quickControlLayout,"modular");compare(SettingsStore.quickControlPanelWidth,448);compare(SettingsStore.quickControlComponentRadius,18);compare(SettingsStore.quickControlOrder[0],"notifications");SettingsStore.resetQuickControlSettings();compare(SettingsStore.quickControlLayout,"classic");compare(SettingsStore.quickControlOrder[0],"notifications");console.log("QUICK CONTROL RELOAD PASS");}}}'''
        assert 'QUICK CONTROL RELOAD PASS' in run_qml(root,env,reload)
        print('PASS: production layouts, regions, reordering, audio amplification, tabs, media, brightness, small screens, palettes and settings restart')


if __name__=='__main__':
    main()
