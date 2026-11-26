#!/usr/bin/env python3
"""Production network cards, gauge, service state and preferences; fake CLI only."""
import json
import argparse
import os
from pathlib import Path
import re
import tempfile
from test_clock_ui import run_qml
from test_glassmorphism_ui import fixture

QML = '''import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtTest
import Quickshell
import Quickshell.Io
import "config"
import "components"
import "services"
import "fixtures" as Fixtures
import "modules/bar"
import "modules/settings/pages"
ShellRoot {
    FileView { id: modeFile; path: Quickshell.shellPath("test-mode"); blockLoading: true }
    Window {
        id: window
        visible: true; width: 820; height: 860
        color: Theme.background
        NetworkPanel { id: network; width:368; height:650; popupScreen:({height:720}) }
        BarSpeedTest { id: second; x:400; width:368 }
        NetworkPanelSettings { id: editor; visible:false; width:720 }
        TestCase {
            name: "NativeSpeedTest"
            when: true
            function card() { return findChild(network,"speedTestCard"); }
            function action() { return findChild(network,"speedTestAction"); }
            function mode(name) { modeFile.setText(name); wait(30); }
            function capture(name) {
                const folder=Quickshell.env("RUSTICQ_SPEED_CAPTURE");
                if(folder){ waitForRendering(second); grabImage(second).save(folder+"/"+name+".png"); }
            }
            function init() {
                tryCompare(SpeedTestService,"checking",false);
                if (SpeedTestService.running) { SpeedTestService.cancel(); tryCompare(SpeedTestService,"running",false); }
                Fixtures.Networking.connected=true;
                SettingsStore.animationsEnabled=false;
                SettingsStore.applyNetworkPanelSettings(SettingsStore.networkPanelDefaults);
                network.visible=true; network.height=650; network.contentY=0;
                findChild(network,"networkWifiCard").advancedOpen=true;
                wait(30);
            }
            function cleanupTestCase() { console.log("SPEED TEST RESULTS",qtest_results.passCount,"passed,",qtest_results.failCount,"failed"); }
            function cleanup() { console.log("SPEED TEST",qtest_results.functionName,"failed",qtest_results.failed,"phase",SpeedTestService.phase,"error",SpeedTestService.error); }
            function test_a_idle_and_sibling_card_geometry() {
                compare(SpeedTestService.phase,"idle");
                compare(SpeedTestService.lastResult,null);
                compare(SpeedTestService.pingMs,-1);
                compare(findChild(card(),"speedTestValue_ping").text,"—");
                const wifi=findChild(network,"networkWifiCard"), speed=card();
                compare(wifi.parent,speed.parent.parent);
                compare(wifi.width,speed.width);
                fuzzyCompare(wifi.x,speed.parent.x,.5);
                fuzzyCompare(speed.parent.y-(wifi.y+wifi.height),Theme.contentGap,.5);
                verify(speed.implicitHeight>=180 && speed.implicitHeight<=245,"height "+speed.implicitHeight);
                wifi.showNetworks(); wait(40);
                compare(findChild(network,"speedTestPanelLoader").item,null);
                fuzzyCompare(network.contentHeight,wifi.height,.5);
                wifi.showAdvanced(); wait(40);
                verify(card()!==null);
                SettingsStore.showSpeedTestPanel=false;
                wait(40);
                const loader=findChild(network,"speedTestPanelLoader");
                compare(loader.active,false); compare(loader.visible,false); compare(loader.item,null);
                fuzzyCompare(network.contentHeight,wifi.height,.5);
                SettingsStore.showSpeedTestPanel=true; wait(40);
                fuzzyCompare(network.contentHeight,wifi.height+Theme.contentGap+card().height,.5);
                network.height=260; verify(network.contentHeight>network.height);
                network.contentY=network.contentHeight-network.height;
                verify(card().mapToItem(network,0,card().height).y<=network.height+.5);
                wifi.showNetworks(); wait(40);
                compare(network.contentY,0);
                compare(findChild(network,"speedTestPanelLoader").item,null);
            }
            function test_b_real_event_states_and_shared_service() {
                mode("success");
                network.contentY=Math.max(0,network.contentHeight-network.height); wait(40);
                mouseClick(action());
                tryCompare(SpeedTestService,"running",true);
                SpeedTestService.start(); // ignored while the first process runs
                tryCompare(SpeedTestService,"phase","ping");
                tryCompare(SpeedTestService,"phase","download");
                compare(SpeedTestService.downloadMbps,100);
                network.visible=false;
                tryCompare(SpeedTestService,"phase","upload");
                compare(findChild(second,"speedTestGauge").phaseLabel,"Upload");
                tryCompare(SpeedTestService,"running",false);
                compare(SpeedTestService.phase,"complete");
                compare(SpeedTestService.pingMs,12.5);
                compare(SpeedTestService.downloadMbps,100);
                compare(SpeedTestService.uploadMbps,20);
                verify(SpeedTestService.lastTestTime>0);
                network.visible=true;
                findChild(network,"networkWifiCard").showAdvanced(); wait(40);
                compare(action().label,"Test Again");
                compare(findChild(second,"speedTestValue_upload").text,"20.0");
                capture("classic-fixture");
                SettingsStore.speedTestPanelStyle="modern"; wait(40); capture("modern-fixture");
                SettingsStore.speedTestPanelStyle="compact"; wait(40); capture("compact-fixture");
            }
            function test_c_cancel_preserves_previous_completed_results() {
                const stamp=SpeedTestService.lastTestTime;
                mode("slow"); SpeedTestService.start();
                tryCompare(SpeedTestService,"phase","download");
                SpeedTestService.cancel();
                tryCompare(SpeedTestService,"running",false);
                compare(SpeedTestService.phase,"cancelled");
                compare(SpeedTestService.downloadMbps,100);
                compare(SpeedTestService.lastTestTime,stamp);
                wait(100); compare(SpeedTestService.phase,"cancelled");
            }
            function test_d_missing_invalid_failed_and_timeout() {
                for(const sample of ["missing","invalid","truncated","error"]){
                    mode(sample); SpeedTestService.start(); tryCompare(SpeedTestService,"running",true); tryCompare(SpeedTestService,"running",false);
                    compare(SpeedTestService.phase,sample==="missing" ? "missing" : "error",sample);
                    compare(action().label,"Retry");
                    verify(findChild(card(),"speedTestStatus").text.length>10);
                }
                mode("slow"); SpeedTestService.start();
                tryCompare(SpeedTestService,"phase","download");
                SpeedTestService.testTimeoutMs=80;
                tryCompare(SpeedTestService,"running",false);
                compare(SpeedTestService.phase,"error");
                verify(SpeedTestService.error.indexOf("timed out")>=0);
                SpeedTestService.testTimeoutMs=130000;
            }
            function test_e_offline_blocks_launch_and_allows_cancel() {
                Fixtures.Networking.connected=false;
                compare(SpeedTestService.state,"offline");
                compare(action().label,"No Connection"); compare(action().enabled,false);
                SpeedTestService.start(); compare(SpeedTestService.running,false);
                Fixtures.Networking.connected=true;
                mode("slow"); SpeedTestService.start(); tryCompare(SpeedTestService,"running",true);
                Fixtures.Networking.connected=false;
                compare(action().label,"Cancel Test"); compare(action().enabled,true);
                SpeedTestService.cancel(); tryCompare(SpeedTestService,"running",false);
            }
            function test_f_styles_density_palette_and_no_gauge_space() {
                for(const density of ["comfortable","compact"]){
                    SettingsStore.uiDensity=density;
                    for(const appearance of ["standard","adaptive","exclusive"]){
                        SettingsStore.glassmorphismEnabled=appearance!=="standard";
                        SettingsStore.rageMode=appearance==="exclusive" ? "exclusive" : "adaptive";
                        for(const style of ["classic","modern","compact"]){
                            SettingsStore.speedTestPanelStyle=style; wait(30);
                            const loader=findChild(card(),"speedTestGaugeLoader");
                            compare(loader.active,style!=="compact");
                            compare(loader.visible,loader.active);
                            if(loader.active){
                                compare(loader.item.modern,style==="modern");
                                compare(loader.item.rangeFor(120),250);
                                compare(loader.item.rangeFor(600),1000);
                                verify(loader.item.rangeFor(15000)>=15000);
                                compare(loader.item.animate,false);
                                compare(loader.item.accentColor,Theme.accent);
                            }
                            SettingsStore.showSpeedometerGauge=false; wait(30);
                            compare(loader.item,null);
                            compare(findChild(card(),"speedTestVerticalDivider").visible,false);
                            const metrics=findChild(card(),"speedTestMetrics");
                            fuzzyCompare(metrics.width,card().width-2*Theme.panelPadding,.5);
                            SettingsStore.showSpeedometerGauge=true;
                        }
                    }
                }
            }
            function test_g_settings_controls_validation_and_persistence() {
                SettingsStore.applyNetworkPanelSettings(SettingsStore.networkPanelDefaults);
                for(const key of Object.keys(SettingsStore.networkPanelDefaults)){
                    verify(!SettingsStore.setNetworkPanelSetting(key,key==="speedTestPanelStyle" ? "unknown" : 1,false));
                }
                editor.visible=true;
                const toggle=findChild(editor,"showSpeedTestPanel");
                toggle.forceActiveFocus(); keyClick(Qt.Key_Space);
                compare(SettingsStore.showSpeedTestPanel,false);
                toggle.forceActiveFocus(); keyClick(Qt.Key_Space);
                compare(SettingsStore.showSpeedTestPanel,true);
                mouseClick(findChild(editor,"speedTestStyle_modern"));
                compare(SettingsStore.speedTestPanelStyle,"modern");
                SettingsStore.setNetworkPanelSetting("showSpeedometerGauge",false,true);
                SettingsStore.setNetworkPanelSetting("speedTestGaugeGlow",true,true);
                SettingsStore.setNetworkPanelSetting("showSpeedTestTime",false,true);
                editor.visible=false;
            }
        }
    }
}
'''

HELPER = '''import json,sys,time
from pathlib import Path
def emit(**event): print(json.dumps(event),flush=True)
if "--probe" in sys.argv:
    emit(phase="ready",backend="ookla");sys.exit(0)
mode=Path(__file__).parents[1].joinpath("test-mode").read_text().strip()
emit(phase="preparing",backend="ookla",progress=0)
time.sleep(.1)
if mode=="missing": emit(phase="missing");sys.exit(2)
if mode=="invalid": print('{"phase":"complete","pingMs":false}',flush=True);time.sleep(5)
if mode=="truncated": sys.exit(0)
if mode=="error": emit(phase="error",message="Test server unavailable. Retry the test.");sys.exit(1)
emit(phase="ping",pingMs=12.5,progress=.1);time.sleep(.2)
emit(phase="download",downloadMbps=100,progress=.4);time.sleep(.25)
if mode=="slow": time.sleep(10)
emit(phase="upload",uploadMbps=20,progress=.8);time.sleep(.25)
emit(phase="complete",pingMs=12.5,downloadMbps=100,uploadMbps=20,progress=1)
'''


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--capture-dir",default="")
    options=parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="rusticq-speedtest-ui-") as folder:
        root=fixture(folder)
        (root/"fixtures").mkdir()
        (root/"fixtures/qmldir").write_text("singleton Networking 1.0 Networking.qml\nsingleton NetworkConnectivity 1.0 NetworkConnectivity.qml\n")
        (root/"fixtures/Networking.qml").write_text('''pragma Singleton
import QtQuick
QtObject { property bool connected:true; property QtObject devices: QtObject {property var values: [{connected:Networking.connected}]}
property bool canCheckConnectivity:false; property bool connectivityCheckEnabled:false; property int connectivity:0 }
''')
        (root/"fixtures/NetworkConnectivity.qml").write_text('pragma Singleton\nimport QtQuick\nQtObject {enum Value { Unknown, None, Portal, Limited, Full }}\n')
        service=root/"services/SpeedTestService.qml"
        service.write_text(service.read_text().replace("import Quickshell.Networking",'import "../fixtures"')
                          .replace('id: service', 'id: service\n    property int testTimeoutMs: 130000')
                          .replace('interval: 130000', 'interval: service.testTimeoutMs'))
        (root/"scripts/rusticq-speedtest.py").write_text(HELPER)
        (root/"scripts/rusticq-wifi-advanced.py").write_text('import json\nprint(json.dumps({"ok":True,"ssid":"Fixture network","interface":"wlan0","rxBytes":0,"txBytes":0}))\n')
        (root/"test-mode").write_text("success")
        env=dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic", QT_QUICK_BACKEND="software",
                 XDG_RUNTIME_DIR=folder, XDG_STATE_HOME=str(root/"state"), XDG_CACHE_HOME=str(root/"cache"))
        if options.capture_dir:
            capture=Path(options.capture_dir).resolve(); capture.mkdir(parents=True,exist_ok=True)
            env["RUSTICQ_SPEED_CAPTURE"]=str(capture)
        output=run_qml(root,env,QML)
        summary=re.search(r"SPEED TEST RESULTS (\d+) passed, (\d+) failed",output)
        assert summary and int(summary[1])>=8 and int(summary[2])==0,output
        saved=json.loads((root/"user-settings.json").read_text())
        assert saved["speedTestPanelStyle"]=="modern" and not saved["showSpeedometerGauge"] and saved["speedTestGaugeGlow"]
        reload='''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {TestCase {when:true;function test_reload(){compare(SettingsStore.speedTestPanelStyle,"modern");compare(SettingsStore.showSpeedometerGauge,false);compare(SettingsStore.speedTestGaugeGlow,true);compare(SettingsStore.showSpeedTestTime,false);console.log("NETWORK SETTINGS RELOAD PASS");}}}'''
        assert "NETWORK SETTINGS RELOAD PASS" in run_qml(root,env,reload)
        print("PASS: production cards, scrolling, states, shared results, cancel, timeout, offline, missing dependency, styles, palettes and persisted settings")


if __name__=="__main__":
    main()
