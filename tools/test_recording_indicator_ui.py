#!/usr/bin/env python3
"""Offscreen status/controls with a PanelWindow model; no real recording."""
import json
import os
from pathlib import Path
import re
import shutil
import sys
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
import "modules/main"
import "modules/settings/pages"

ShellRoot {
    id: suite
    function attachPanel(panel) {
        Qt.callLater(function() { if (panel && panel.contentItem) panel.contentItem.parent = recordingLayer; });
    }
    Component.onCompleted: attachPanel(indicator)
    RecordingIndicator { id: indicator; screen: Quickshell.screens[0] }
    Loader {
        id: secondDisplay
        sourceComponent: Component { RecordingIndicator { screen: Quickshell.screens[0] } }
        onLoaded: suite.attachPanel(item)
    }
    FileView {
        id: recorderState
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rusticq-recorder/active.json"
        blockWrites: true
        printErrors: false
    }
    Window {
        id: testWindow
        visible: true
        width: 720; height: 880
        color: Theme.background
        RecordingIndicatorSettings { id: editor; x: 16; y: 16; width: 680 }
        Item { id: recordingLayer; x: 660; y: 16; width: 48; height: 48 }
        TestCase {
            name: "RecordingIndicator"
            when: true
            property bool captured: false
            function descendants(item) {
                let items = [item];
                for (const child of item.children) items = items.concat(descendants(child));
                return items;
            }
            function find(name, parent) {
                const item = descendants(parent || editor).find(child => child.objectName === name);
                verify(item !== undefined, name);
                return item;
            }
            function click(name) {
                const item = find(name);
                mouseClick(item, item.width / 2, item.height / 2);
                wait(30);
            }
            function status(value, refresh) {
                recorderState.setText(JSON.stringify(value));
                if (refresh !== false) ScreenRecorder.refresh();
            }
            function init() {
                secondDisplay.active = true;
                SettingsStore.recordingIndicatorEnabled = true;
                SettingsStore.recordingIndicatorBlink = true;
                SettingsStore.recordingIndicatorCorner = "top-right";
                SettingsStore.recordingIndicatorSize = 12;
                SettingsStore.recordingIndicatorOffsetX = 24;
                SettingsStore.recordingIndicatorOffsetY = 64;
                status({active:false});
                tryCompare(ScreenRecorder, "active", false);
                wait(30);
            }
            function cleanup() { console.log("RECORDING TEST " + qtest_results.functionName + " failed=" + qtest_results.failed); }
            function cleanupTestCase() { console.log("RECORDING RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed"); }
            function test_idle_active_stop_and_native_state_refresh() {
                verify(!indicator.visible);
                status({active:true, file:"/tmp/fake-recording.mp4"}, false);
                tryCompare(ScreenRecorder, "active", true, 2000);
                verify(indicator.visible);
                verify(secondDisplay.item.visible);
                compare(ScreenRecorder.outputFile, "/tmp/fake-recording.mp4");
                status({active:false});
                tryCompare(ScreenRecorder, "active", false);
                verify(!indicator.visible);
                verify(!secondDisplay.item.visible);
                compare(ScreenRecorder.outputFile, "");
            }
            function test_blinking_and_steady_light() {
                status({active:true});
                tryCompare(indicator, "visible", true);
                const dot = find("recordingDot", indicator.contentItem);
                tryCompare(dot, "animating", true);
                const initial = dot.opacity;
                tryVerify(() => Math.abs(dot.opacity - initial) > .15, 1500);
                click("recordingIndicatorBlink-toggle");
                compare(SettingsStore.recordingIndicatorBlink, false);
                tryCompare(dot, "animating", false);
                compare(dot.opacity, 1);
                click("recordingIndicatorBlink-toggle");
                tryCompare(dot, "animating", true);
                status({active:false});
                tryCompare(indicator, "visible", false);
                tryCompare(dot, "animating", false);
            }
            function test_corners_offsets_and_unloaded_display() {
                status({active:true});
                tryCompare(indicator, "visible", true);
                for (const corner of ["top-left", "top-right", "bottom-left", "bottom-right"]) {
                    click("recordingIndicatorCorner-" + corner);
                    compare(SettingsStore.recordingIndicatorCorner, corner);
                    compare(indicator.anchors.top, corner.indexOf("top-") === 0);
                    compare(indicator.anchors.bottom, corner.indexOf("bottom-") === 0);
                    compare(indicator.anchors.right, corner.endsWith("-right"));
                    compare(indicator.anchors.left, corner.endsWith("-left"));
                    compare(secondDisplay.item.atTop, indicator.atTop);
                    compare(secondDisplay.item.atRight, indicator.atRight);
                }
                SettingsStore.updateRecordingIndicator("recordingIndicatorOffsetX", 72, false);
                SettingsStore.updateRecordingIndicator("recordingIndicatorOffsetY", 84, false);
                compare(indicator.margins.right, 72);
                compare(indicator.margins.bottom, 84);
                secondDisplay.active = false;
                wait(30);
                verify(indicator.visible && ScreenRecorder.active);
                secondDisplay.active = true;
                tryVerify(() => secondDisplay.item !== null);
                verify(secondDisplay.item.visible);
                compare(secondDisplay.item.margins.right, 72);
                compare(secondDisplay.item.margins.bottom, 84);
            }
            function test_toggle_independent_of_bar_and_click_through_configuration() {
                status({active:true});
                tryCompare(indicator, "visible", true);
                SettingsStore.barVisible = false;
                verify(indicator.visible);
                compare(indicator.focusable, false);
                verify(indicator.mask !== null);
                compare(indicator.mask.width, 0);
                compare(indicator.mask.height, 0);
                click("recordingIndicatorEnabled-toggle");
                verify(!indicator.visible);
                verify(ScreenRecorder.active);
                click("recordingIndicatorEnabled-toggle");
                verify(indicator.visible);
                SettingsStore.barVisible = true;
            }
            function test_slider_and_validation() {
                const slider = find("recordingIndicatorSize-slider");
                mouseClick(slider, slider.width - 9, slider.height / 2);
                compare(SettingsStore.recordingIndicatorSize, 24);
                compare(indicator.implicitWidth, 36);
                mouseClick(slider, 9, slider.height / 2);
                compare(SettingsStore.recordingIndicatorSize, 8);
                compare(indicator.implicitWidth, 20);
                verify(!SettingsStore.setRecordingIndicatorCorner("unknown"));
                verify(!SettingsStore.updateRecordingIndicator("wallpaperPath", 99));
                verify(!SettingsStore.updateRecordingIndicator("recordingIndicatorSize", NaN));
                verify(!SettingsStore.updateRecordingIndicator("recordingIndicatorSize", Infinity));
                SettingsStore.updateRecordingIndicator("recordingIndicatorOffsetX", -50, false);
                compare(SettingsStore.recordingIndicatorOffsetX, 0);
                SettingsStore.updateRecordingIndicator("recordingIndicatorSize", 999, false);
                compare(SettingsStore.recordingIndicatorSize, 24);
            }
            function test_invalid_status_and_failed_stop() {
                status({active:true});
                tryCompare(ScreenRecorder, "active", true);
                ScreenRecorder.action("stop");
                verify(ScreenRecorder.active);
                wait(1700);
                verify(ScreenRecorder.active && indicator.visible);
                status({active:true, malformed:true});
                tryCompare(ScreenRecorder, "active", false);
                verify(!indicator.visible);
                status({active:true, exitCode:1});
                wait(250);
                compare(ScreenRecorder.active, false);
                verify(!indicator.visible);
            }
            function test_z_save_and_preview() {
                click("recordingIndicatorCorner-bottom-left");
                SettingsStore.updateRecordingIndicator("recordingIndicatorSize", 18);
                SettingsStore.updateRecordingIndicator("recordingIndicatorOffsetX", 44);
                SettingsStore.updateRecordingIndicator("recordingIndicatorOffsetY", 82);
                click("recordingIndicatorBlink-toggle");
                editor.grabToImage(function(result) { captured = result.saveToFile("/tmp/rusticq-recording-settings.png"); });
                tryVerify(() => captured, 1500);
                compare(ScreenRecorder.active, false);
            }
        }
    }
}
'''


def main():
    with tempfile.TemporaryDirectory(prefix='rusticq-recording-ui-') as folder:
        root = Path(folder)
        for name in ('components', 'config', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        # The offscreen Qt platform has no layer-shell PanelWindow backend.
        # Keep its geometry bindings while exercising real QML content/service.
        fixtures = root / 'fixtures'
        fixtures.mkdir()
        (fixtures / 'AnchorEdges.qml').write_text('''import QtQuick
QtObject {
    property bool top: false
    property bool bottom: false
    property bool left: false
    property bool right: false
}
''')
        (fixtures / 'Insets.qml').write_text('''import QtQuick
QtObject {
    property real top: 0
    property real bottom: 0
    property real left: 0
    property real right: 0
}
''')
        (fixtures / 'PanelWindow.qml').write_text('''import QtQuick
QtObject {
    id: root
    default property alias data: content.data
    property var screen: null
    property bool visible: false
    property color color: "transparent"
    property bool focusable: true
    property int exclusionMode: 0
    property var mask: null
    property real implicitWidth: 0
    property real implicitHeight: 0
    property AnchorEdges anchors: AnchorEdges {}
    property Insets margins: Insets {}
    readonly property Item contentItem: Item {
        id: content
        width: root.implicitWidth
        height: root.implicitHeight
        visible: root.visible
    }
}
''')
        overlay = root / 'modules/main/RecordingIndicator.qml'
        overlay.write_text(overlay.read_text().replace('import QtQuick\n', 'import QtQuick\nimport "../../fixtures" as Headless\n', 1)
                           .replace('PanelWindow {', 'Headless.PanelWindow {', 1)
                           .replace('    WlrLayershell.layer: WlrLayer.Overlay\n', ''))
        state = root / 'rusticq-recorder/active.json'
        state.parent.mkdir()
        state.write_text('{"active":false}')
        (root / 'user-settings.json').write_text('{"showWifi":true,"clockFormat":"HH:mm:ss"}')
        (root / 'scripts').mkdir()
        (root / 'scripts/rustiq-record.py').write_text('''import json,os,sys
from pathlib import Path
path = Path(os.environ['XDG_RUNTIME_DIR']) / 'rusticq-recorder/active.json'
if sys.argv[1] != 'status':
    print(json.dumps({'ok':False,'message':'Mock stop refused'}))
    raise SystemExit(1)
data = json.loads(path.read_text())
print('{invalid' if data.get('malformed') else json.dumps(dict(data,ok=True)))
raise SystemExit(data.get('exitCode',0))
''')
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder)
        output = run_qml(root, env, QML)
        summary = re.search(r'RECORDING RESULTS (\d+) passed, (\d+) failed', output)
        assert summary and int(summary[1]) >= 7 and int(summary[2]) == 0, output
        saved = json.loads((root / 'user-settings.json').read_text())
        expected = dict(recordingIndicatorEnabled=True, recordingIndicatorBlink=False,
                        recordingIndicatorCorner='bottom-left', recordingIndicatorSize=18,
                        recordingIndicatorOffsetX=44, recordingIndicatorOffsetY=82)
        for key, value in dict(expected, showWifi=True, clockFormat='HH:mm:ss').items():
            assert saved[key] == value, (key, saved.get(key), value)
        checks = '\n'.join(f'compare(SettingsStore.{key}, {json.dumps(value)});' for key, value in expected.items())
        reload_qml = '''import QtQuick
import QtTest
import Quickshell
import "config"
ShellRoot {
    TestCase {
        when: true
        function test_reload() {
            CHECKS
            console.log("RECORDING RELOAD PASS");
        }
    }
}
'''
        assert 'RECORDING RELOAD PASS' in run_qml(root, env, reload_qml.replace('CHECKS', checks))
    print('PASS: recording lifecycle, native status refresh, blinking, corners, insets, visibility, display recreation and save/reload')


def native_smoke():
    """Load the real Wayland overlay while inactive; never show or record anything."""
    runtime = os.environ.get('XDG_RUNTIME_DIR', '')
    display = os.environ.get('WAYLAND_DISPLAY', '')
    if not runtime or not display:
        raise SystemExit('A Wayland session is required for the inactive native smoke check')
    socket = str(Path(display) if Path(display).is_absolute() else Path(runtime) / display)
    with tempfile.TemporaryDirectory(prefix='rusticq-recording-native-') as folder:
        root = Path(folder)
        for name in ('components', 'config', 'services', 'assets', 'modules'):
            shutil.copytree(ROOT / name, root / name)
        (root / 'user-settings.json').write_text('{}')
        (root / 'services/ScreenRecorder.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { readonly property bool active: false }\n')
        source = '''import QtQuick
import Quickshell
import "config"
import "modules/main"
ShellRoot {
    RecordingIndicator { id: indicator; screen: Quickshell.screens[0] }
    Timer {
        interval: 250
        running: true
        onTriggered: {
            if (!indicator.visible && !indicator.focusable && indicator.mask.width === 0
                    && indicator.mask.height === 0 && indicator.exclusionMode === ExclusionMode.Ignore
                    && indicator.anchors.top && indicator.anchors.right)
                console.log("NATIVE RECORDING INDICATOR LOAD PASS");
            else console.error("Native recording indicator configuration failed");
            Qt.quit();
        }
    }
}
'''
        env = dict(os.environ, QT_QPA_PLATFORM='wayland', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder, WAYLAND_DISPLAY=socket,
                   XDG_STATE_HOME=str(root / 'state'), XDG_DATA_HOME=str(root / 'data'),
                   XDG_CONFIG_HOME=str(root / 'user-config'), XDG_CACHE_HOME=str(root / 'cache'),
                   HOME=str(root / 'home'))
        output = run_qml(root, env, source)
        assert 'NATIVE RECORDING INDICATOR LOAD PASS' in output, output
    print('PASS: real Wayland PanelWindow and input mask load while inactive; no recording or visible test overlay')


if __name__ == '__main__':
    native_smoke() if '--native-smoke' in sys.argv[1:] else main()
