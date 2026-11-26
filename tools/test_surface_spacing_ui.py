#!/usr/bin/env python3
"""Measure production content insets across density and palette changes in Qt Quick.

Isolated HOME/state and fixture weather; never modifies desktop/network settings.
Connectivity rows are covered by test_wifi_audio_ui.py; native-window inset
ownership is also exercised by capture_rage_materials.py.
"""
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
import "config"
import "components"
import "modules/main"
import "modules/bar"
import "modules/settings"
import "modules/settings/pages"
ShellRoot {
    Window {
        visible:true;width:440;height:760
        Loader {id:probe;width:400;height:700}
        Component {id:spacingEditor;SurfaceSpacingSettings {}}
        TestCase {
            name:"SurfaceSpacing"
            when:true
            function cleanupTestCase(){console.log("SPACING RESULTS",qtest_results.passCount,"passed,",qtest_results.failCount,"failed");}
            function init(){SettingsStore.applySurfaceSpacingSettings(SettingsStore.surfaceSpacingDefaults);}
            function test_production_content_insets_live(){
                SettingsStore.animationsEnabled=false;
                for(const path of ["modules/settings/SettingsSection.qml","modules/main/MiniTime.qml","modules/main/MiniDate.qml",
                    "modules/main/MiniWeather.qml","modules/main/MiniAudio.qml","modules/main/MiniEthernetInfo.qml",
                    "modules/main/SystemDashboard.qml","modules/main/DesktopScratchpadCard.qml","modules/main/DesktopNotesCard.qml",
                    "modules/bar/BarBattery.qml","modules/bar/BarBluetooth.qml"]){
                    probe.source=Qt.resolvedUrl(path);tryVerify(()=>probe.item!==null,5000,path);
                    const content=findChild(probe.item,"surfaceContent");verify(content!==null,path);
                    for(const density of ["comfortable","compact"]){
                        SettingsStore.uiDensity=density;
                        for(const provider of ["standard","adaptive","exclusive"]){
                            SettingsStore.glassmorphismEnabled=provider!=="standard";
                            SettingsStore.rageMode=provider==="exclusive" ? "exclusive" : "adaptive";
                            for(const manual of [-1,0,24]){
                                SettingsStore.setSurfaceSpacing("surfacePanelPadding",manual,false);wait(20);
                                fuzzyCompare(content.mapToItem(probe.item,0,0).x,Theme.panelPadding,.75,path+" left "+density+" "+provider+" "+manual);
                                fuzzyCompare(content.width,probe.item.width-2*Theme.panelPadding,.75,path+" width "+density+" "+provider+" "+manual);
                            }
                        }
                    }
                    probe.source="";
                }
            }
            function test_validation_manual_controls_and_commit(){
                for(const key of Object.keys(SettingsStore.surfaceSpacingDefaults)){
                    compare(SettingsStore[key],-1);
                    for(const bad of [true,false,null,"12",-2,1000,1.5]){
                        compare(SettingsStore.setSurfaceSpacing(key,bad,false),false);compare(SettingsStore[key],-1);
                    }
                }
                probe.source="";probe.sourceComponent=spacingEditor;tryVerify(()=>probe.item!==null);
                const slider=findChild(probe.item,"surfacePanelPaddingSlider");verify(slider!==null);
                const snapshot=SettingsStore.settingsSnapshot;
                slider.preview(22);compare(Theme.panelPadding,22);compare(SettingsStore.settingsSnapshot,snapshot);
                slider.commit(22);compare(JSON.parse(SettingsStore.settingsSnapshot).surfacePanelPadding,22);
                slider.forceActiveFocus();keyClick(Qt.Key_Right);compare(Theme.panelPadding,23);
                mouseClick(findChild(probe.item,"surfacePanelPaddingAuto"));compare(SettingsStore.surfacePanelPadding,-1);
                compare(Theme.panelPadding,SettingsStore.uiDensity==="compact" ? 12 : 16);
                SettingsStore.setSurfaceSpacing("surfaceContentGap",18,false);
                mouseClick(findChild(probe.item,"resetSurfaceSpacing"));compare(SettingsStore.surfaceContentGap,-1);
                SettingsStore.setSurfaceSpacing("surfacePanelPadding",21,true);
                SettingsStore.setSurfaceSpacing("surfaceInlineGap",9,true);
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-spacing-ui-') as folder:
        root=fixture(folder)
        (root/'home').mkdir()
        (root/'services/WeatherService.qml').write_text('''pragma Singleton
import QtQuick
QtObject {property string temperature:"24°C";property string feelsLike:"25°C";property string location:"Example City";property string condition:"Partly cloudy";property string icon:"\\uf172";property bool loading:false;property string lastError:"";property double lastUpdated:0;function refresh(){}}
''')
        env=dict(os.environ,HOME=str(root/'home'),XDG_STATE_HOME=str(root/'state'),
                 XDG_RUNTIME_DIR=folder,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',QT_QUICK_BACKEND='software')
        output=run_qml(root,env,QML)
        summary=re.search(r'SPACING RESULTS (\d+) passed, (\d+) failed',output)
        assert summary and int(summary[1])>=3 and int(summary[2])==0,output
        reload_qml='''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {TestCase {when:true;function test_reload(){compare(SettingsStore.surfacePanelPadding,21);compare(SettingsStore.surfaceInlineGap,9);compare(Theme.panelPadding,21);console.log("SPACING RELOAD PASS");}}}'''
        assert 'SPACING RELOAD PASS' in run_qml(root,env,reload_qml)
        print('PASS: 11 production content layouts × 2 densities × 3 palette/material modes × 3 padding choices; manual controls, validation, commit-only save and restart')


if __name__=='__main__':
    main()
