#!/usr/bin/env python3
"""Weather parsing/fetch/retry/layout and transformed outside-click behavior.

Uses the real WeatherService and UI with an isolated curl fixture, no network.
"""
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from test_clock_ui import run_qml

ROOT = Path(__file__).resolve().parents[1]
QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "config"
import "services"
import "components"
import "modules/main"
ShellRoot {
    FileView { id:mode;path:Qt.resolvedUrl("mode");blockLoading:true }
    FileView { id:count;path:Qt.resolvedUrl("count");blockLoading:true }
    Window {
        id:scene;visible:true;width:720;height:1000;color:Theme.background
        MiniWeather { id:weatherView;width:350;height:implicitHeight }
        OutsideClickArea { id:outside;anchors.fill:parent;surface:panel }
        Rectangle {
            id:panel;x:400;y:500;width:260;height:180;color:Theme.surface
            ActionButton { id:button;anchors.centerIn:parent;label:"Inside" }
        }
        SignalSpy { id:outsideClicks;target:outside;signalName:"outsideClicked" }
        SignalSpy { id:buttonClicks;target:button;signalName:"clicked" }
        TestCase {
            when:true
            name:"WeatherAndPopup"
            function observation(temp,feels,summary,area) {
                return JSON.stringify({current_condition:[{temp_C:temp,FeelsLikeC:feels,weatherDesc:[{value:summary}]}],
                    nearest_area:[{areaName:[{value:area}],region:[{value:"Region"}],country:[{value:"Test Country"}]}]});
            }
            function initTestCase() {
                SettingsStore.animationsEnabled=false;
                WeatherService.refresh();
                tryCompare(WeatherService,"loading",false);
                tryCompare(WeatherService,"temperature","27°C");
                wait(30);
            }
            function init() {
                mode.setText("ok");
                weatherView.height=Qt.binding(() => weatherView.implicitHeight);
                panel.scale=1;
                outsideClicks.clear();buttonClicks.clear();
                wait(20);
            }
            function cleanup() { console.log("WEATHER TEST "+qtest_results.functionName+" failed="+qtest_results.failed); }
            function cleanupTestCase() { console.log("WEATHER RESULTS "+qtest_results.passCount+" passed, "+qtest_results.failCount+" failed"); }
            function test_valid_json_units_location_and_semicolon_conditions() {
                verify(WeatherService.applyResponse(observation("-3","-7","Light snow; mist","Example City")));
                compare(WeatherService.temperature,"-3°C");compare(WeatherService.feelsLike,"-7°C");
                compare(WeatherService.location,"Example City, Test Country");
                compare(WeatherService.condition,"Light snow; mist");
                verify(WeatherService.lastUpdated>0);compare(WeatherService.lastError,"");
                verify(WeatherService.applyResponse(observation(0,0,"Clear","Zero")));
                compare(WeatherService.temperature,"0°C");compare(WeatherService.feelsLike,"0°C");
            }
            function test_invalid_data_keeps_last_observation() {
                WeatherService.applyResponse(observation(25,28,"Rain","Saved City"));
                const stamp=WeatherService.lastUpdated;
                for(const invalid of ['<html>Service unavailable</html>','{broken','null','{}',
                    observation(false,0,"Rain","Bad"),observation("",0,"Rain","Bad"),
                    observation("NaN",0,"Rain","Bad"),observation(999,0,"Rain","Bad"),
                    observation(22,0,"","Bad")]) {
                    verify(!WeatherService.applyResponse(invalid));
                    compare(WeatherService.temperature,"25°C");
                    compare(WeatherService.location,"Saved City, Test Country");
                    compare(WeatherService.lastUpdated,stamp);
                    verify(WeatherService.lastError.length>0);
                }
                verify(WeatherService.applyResponse(observation(26,null,"Sunny","Restored")));
                compare(WeatherService.lastError,"");compare(WeatherService.feelsLike,"");
            }
            function test_missing_optional_fields_are_readable() {
                verify(WeatherService.applyResponse(JSON.stringify({current_condition:[{temp_C:21,weatherDesc:[{value:"Clear"}]}]})));
                compare(WeatherService.location,"");compare(WeatherService.feelsLike,"");
                compare(WeatherService.temperature,"21°C");
            }
            function test_fetch_single_request_and_error_recovery() {
                count.reload();const before=Number(count.text());
                WeatherService.refresh();WeatherService.refresh();
                compare(WeatherService.loading,true);
                compare(findChild(weatherView,"weatherRefreshButton").enabled,false);
                tryCompare(WeatherService,"loading",false);
                compare(WeatherService.temperature,"27°C");
                count.reload();compare(Number(count.text()),before+1);
                mode.setText("error");wait(30);
                WeatherService.refresh();tryCompare(WeatherService,"loading",false);
                verify(WeatherService.lastError.length>0);
                compare(WeatherService.temperature,"27°C");
                mode.setText("ok");wait(30);
                WeatherService.refresh();tryCompare(WeatherService,"loading",false);
                compare(WeatherService.lastError,"");
            }
            function test_long_weather_and_short_viewport_scroll() {
                WeatherService.applyResponse(observation(27,32,"Heavy rain with thunderstorms and extensive cloud cover. ".repeat(6),"A city with a long name"));
                wait(30);
                verify(weatherView.implicitHeight>262);
                const scroll=findChild(weatherView,"weatherScroll");
                fuzzyCompare(scroll.contentHeight,weatherView.implicitHeight,.1);
                weatherView.height=140;wait(30);
                verify(scroll.contentHeight>scroll.height);
                scroll.contentY=scroll.contentHeight-scroll.height;
                verify(scroll.contentY>0);
                compare(findChild(weatherView,"weatherStatus").visible,true);
            }
            function test_outside_click_does_not_close_panel_padding_or_controls() {
                mouseClick(panel,10,10);compare(outsideClicks.count,0);
                mouseClick(button);compare(buttonClicks.count,1);compare(outsideClicks.count,0);
                mouseClick(outside,10,900);compare(outsideClicks.count,1);
                panel.scale=.8;
                mouseClick(panel,10,10);compare(outsideClicks.count,1);
                mouseClick(outside,panel.x+2,panel.y+2);compare(outsideClicks.count,2);
                mouseClick(outside,10,900,Qt.RightButton);compare(outsideClicks.count,3);
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-weather-ui-') as folder:
        root=Path(folder)
        for name in ('config','components','services','modules','assets'):
            shutil.copytree(ROOT/name,root/name)
        (root/'user-settings.json').write_text('{}')
        (root/'mode').write_text('ok')
        (root/'count').write_text('0')
        (root/'bin').mkdir()
        curl=root/'bin/curl'
        curl.write_text('''#!/usr/bin/env python3
import json,sys,time
from pathlib import Path
root=Path(__file__).resolve().parents[1]
counter=root/'count';counter.write_text(str(int(counter.read_text())+1))
time.sleep(.08)
if (root/'mode').read_text()=='error':
 print('Network unavailable',file=sys.stderr);raise SystemExit(22)
assert sys.argv[-1]=='https://wttr.in/?format=j1&m'
print(json.dumps({'current_condition':[{'temp_C':'27','FeelsLikeC':'30','weatherDesc':[{'value':'Light rain'}]}],
 'nearest_area':[{'areaName':[{'value':'Fixture City'}],'country':[{'value':'Fixture Country'}]}]}))
''')
        curl.chmod(0o755)
        env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QPA_PLATFORMTHEME='generic',
                 QT_QUICK_BACKEND='software',XDG_RUNTIME_DIR=folder,PATH=str(root/'bin')+os.pathsep+os.environ['PATH'])
        output=run_qml(root,env,QML)
        summary=re.search(r'WEATHER RESULTS (\d+) passed, (\d+) failed',output)
        assert summary and int(summary[1])>=7 and int(summary[2])==0,output
    print('PASS: weather JSON, Celsius/location, bad-data fallback, deduplicated refresh, scrolling, inside/outside clicks')


if __name__=='__main__':
    main()
