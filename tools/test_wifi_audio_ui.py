#!/usr/bin/env python3
"""Offscreen connectivity search, Wi-Fi navigation and audio with fake devices."""
import json
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
NATIVE_QML = '''import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "config"
import "modules/main"
ShellRoot {
    id: suite
    property int keyboardExitCode: -1
    property string phase: ""
    Process { id:keyboard;command:["wtype","g"];onExited:(code,status)=>suite.keyboardExitCode=code
        stderr:StdioCollector { onStreamFinished: if(this.text) console.log("Native keyboard diagnostic:",this.text) }
    }
    PanelWindow {
        id: host
        WlrLayershell.namespace: "rusticq-search-focus-test"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None // injected from the production bar binding
        readonly property string miniKind: popup.kind
        readonly property bool requested: true
        screen: Quickshell.screens[0]
        anchors { top: true; right: true }
        margins { top: 140; right: 20 }
        implicitWidth: 400; implicitHeight: 36
        property int barHeight: 36
        exclusionMode: ExclusionMode.Ignore
        color: Theme.background
    }
    IndicatorPopup {
        id: popup
        hostWindow: host
        onDismissed: kind = ""
        TestCase {
            name: "NativeConnectivityFocus"
            when: true
            function cleanupTestCase() {
                popup.kind = "";
                console.log("NATIVE SEARCH RESULTS " + qtest_results.passCount + " passed, " + qtest_results.failCount + " failed");
            }
            function cleanup() { console.log("NATIVE PHASE",suite.phase,"failed",qtest_results.failed); }
            function test_popup_qml_focus_keyboard_policy_and_retained_reopen() {
                for (const animated of [false, true]) {
                    SettingsStore.animationsEnabled = animated;
                    for (const kind of ["wifi", "bluetooth"]) {
                        for (let attempt=0; attempt<2; attempt++) {
                            popup.kind = kind;
                            suite.phase="opening "+kind;
                            tryCompare(popup,"visible",true);
                            const name = kind === "wifi" ? "wifiNameSearch" : "bluetoothNameSearch";
                            tryVerify(() => findChild(popup.contentItem,name) !== null);
                            const field = findChild(popup.contentItem,name);
                            const input = findChild(field,"nameSearchInput");
                            tryCompare(input,"activeFocus",true);
                            wait(120);
                            tryCompare(input,"activeFocus",true);
                            tryCompare(popup,"outsideGrabActive",true);
                            compare(popup.WlrLayershell.keyboardFocus,WlrKeyboardFocus.OnDemand);
                            suite.phase="native window focus";
                            tryCompare(popup.contentItem.Window.window,"active",true);
                            field.text = "";
                            // Inject only when the native Wayland window owns
                            // focus, using the unchanged production policy.
                            verify(input.activeFocus && popup.visible && popup.contentItem.Window.active);
                            suite.keyboardExitCode=-1;
                            keyboard.running=true;tryCompare(keyboard,"running",false);
                            suite.phase="keyboard exit "+suite.keyboardExitCode;
                            tryCompare(suite,"keyboardExitCode",0);
                            suite.phase="native typed text: "+field.text;
                            tryCompare(field,"text","g");
                            compare(field.text,"g");
                            tryCompare(input,"activeFocus",true);
                            suite.phase="escape";
                            keyClick(Qt.Key_Escape);
                            compare(field.text,"");
                            compare(popup.visible,true);
                            popup.kind = "";
                            compare(popup.dismissalArmed,false);
                            tryCompare(popup,"visible",false);
                            compare(host.WlrLayershell.keyboardFocus,WlrKeyboardFocus.None);
                            wait(180);compare(popup.kind,"");
                        }
                    }
                }
                // Destroy pending fields before the deferred focus fires.
                popup.kind="wifi"; popup.kind="bluetooth"; popup.kind="";
                tryCompare(popup,"visible",false);
                wait(30);
            }
            function test_switching_and_other_panel_handoff() {
                SettingsStore.animationsEnabled=true;
                popup.kind="wifi";
                tryCompare(popup,"outsideGrabActive",true);
                wait(200);compare(popup.kind,"wifi");
                popup.kind="bluetooth";
                tryCompare(popup,"outsideGrabActive",true);
                wait(200);compare(popup.kind,"bluetooth");
                Store.barPopupOpened(host);
                compare(popup.kind,"bluetooth");
                Store.barPopupOpened(suite);
                compare(popup.kind,"");
                tryCompare(popup,"visible",false);
                for (const property of ["sidebarVisible","launcherVisible","aiVisible","powerMenuVisible"]) {
                    popup.kind="wifi";
                    tryCompare(popup,"outsideGrabActive",true);
                    Store[property]=true;
                    compare(popup.kind,"");
                    compare(popup.dismissalArmed,false);
                    Store[property]=false;
                    tryCompare(popup,"visible",false);
                }
            }
        }
    }
}
'''


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture-dir', default='')
    parser.add_argument('--native-smoke', action='store_true',
                        help='Wayland panel focus/keyboard policy and wtype input, with fake device adapters')
    options = parser.parse_args()
    if options.capture_dir:
        Path(options.capture_dir).mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='rusticq-wifi-audio-ui-') as folder:
        target = Path(folder)
        for name in ('config', 'components', 'services', 'assets'):
            shutil.copytree(ROOT / name, target / name)
        shutil.copytree(ROOT / 'modules', target / 'modules')
        (target / 'tests').mkdir()
        shutil.copyfile(ROOT / 'tools/WifiAudioInteraction.qml', target / 'tests/Interaction.qml')
        interaction = target / 'tests/Interaction.qml'
        interaction.write_text(interaction.read_text().replace('import "../services"', 'import "../services"\nimport "../fixtures"\nimport "../fixtures" as Fixtures', 1))
        (target / 'user-settings.json').write_text('{}')
        (target / 'fixtures').mkdir()
        (target / 'fixtures/qmldir').write_text('singleton Pipewire 1.0 Pipewire.qml\nPwObjectTracker 1.0 PwObjectTracker.qml\nPwNodePeakMonitor 1.0 PwNodePeakMonitor.qml\nsingleton PwAudioChannel 1.0 PwAudioChannel.qml\nsingleton WifiFixture 1.0 WifiFixture.qml\nsingleton Bluetooth 1.0 Bluetooth.qml\n')
        (target / 'fixtures/WifiFixture.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property QtObject adapter: QtObject {
        property string name: "wlan0"
        property QtObject networks: QtObject { property var values: [] }
    }
    property var device: adapter
}
''')
        (target / 'fixtures/Bluetooth.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property QtObject adapter: QtObject {
        property bool enabled: true
        property bool discovering: false
        property QtObject devices: QtObject { property var values: [] }
    }
    property var defaultAdapter: adapter
}
''')
        bluetooth = target / 'modules/bar/BarBluetooth.qml'
        bluetooth.write_text(bluetooth.read_text().replace('import Quickshell.Bluetooth as Native', 'import "../../fixtures" as Native'))
        (target / 'fixtures/Pipewire.qml').write_text('''pragma Singleton
import QtQuick
QtObject {
    property QtObject nodes: QtObject { property var values: [] }
    property var defaultAudioSink: null
    property var defaultAudioSource: null
    property var preferredDefaultAudioSink: null
    property var preferredDefaultAudioSource: null
}
''')
        (target / 'fixtures/PwObjectTracker.qml').write_text('import QtQuick\nQtObject { property var objects: [] }\n')
        (target / 'fixtures/PwNodePeakMonitor.qml').write_text('import QtQuick\nQtObject { property var node; property bool enabled: true; property real peak: 0.5 }\n')
        (target / 'fixtures/PwAudioChannel.qml').write_text('pragma Singleton\nimport QtQuick\nQtObject { enum Channel { Unknown } }\n')
        mixer = target / 'components/ApplicationAudioMixer.qml'
        mixer.write_text(mixer.read_text().replace('import Quickshell.Services.Pipewire', 'import "../fixtures"'))
        audio = target / 'modules/main/MiniAudio.qml'
        audio.write_text(audio.read_text().replace('import Quickshell.Services.Pipewire', 'import "../../fixtures"'))
        (target / 'services/WifiService.qml').write_text('''pragma Singleton
import QtQuick
import Quickshell.Networking
QtObject {
    property var wifiDevice: ({name: "wlan0"})
    property bool enabled: true
    property var connectedNetwork: null
    property bool portalDetected: false
    readonly property bool portalAvailable: enabled && wifiDevice !== null && connectedNetwork !== null
        && (connectedNetwork.security === WifiSecurityType.Open || portalDetected)
    property bool portalLaunchSucceeds: true
    property int portalCalls: 0
    function openPortal() {
        if (!portalAvailable) return false;
        portalCalls++; return portalLaunchSucceeds;
    }
    property bool hiddenConnecting: false
    property bool hiddenFailed: false
    property string hiddenMessage: ""
    property int calls: 0
    property string requestedSsid: ""
    property string requestedSecurity: ""
    function connectHidden(ssid, security, password) {
        calls++; requestedSsid = ssid; requestedSecurity = security;
        hiddenConnecting = true; return true;
    }
}
''')
        (target / 'services/WifiManager.qml').write_text('''import QtQuick
import "../fixtures"
QtObject {
    property var wifiDevice: WifiFixture.device
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property bool scanning: false
    property var processingNetwork: null
    function toggleScan() {}
    function toggleWifi() {}
    function signalIcon(strength) { return strength >= .75 ? "\\ue1d8" : strength >= .5 ? "\\uebe1" : strength >= .25 ? "\\uebd6" : "\\uebe4"; }
    function stateText(network) { return network.connected ? "Connected" : "Available"; }
    function clearProcessing(network) { processingNetwork = null; }
    function connectNetwork(network) { network.connect(); }
    function disconnectNetwork(network) { network.connected = false; }
}
''')
        (target / 'scripts').mkdir()
        (target / 'scripts/rusticq-wifi-advanced.py').write_text(
            'import json\nprint(json.dumps({"ok": True, "ssid": "Test network", "interface": "wlan0", "rxBytes": 0, "txBytes": 0}))\n')
        (target / 'scripts/rustiq-settings-float.py').write_text('pass\n')
        (target / 'scripts/rusticq-audio-peak.py').write_text('import time\nprint("0.25", flush=True)\ntime.sleep(5)\n')
        (target / 'shell.qml').write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import "tests"
ShellRoot { Window { visible: true; width: 780; height: 900; Interaction {} } }
''')
        if options.native_smoke:
            if not os.environ.get('WAYLAND_DISPLAY'):
                raise SystemExit('A Wayland session is required for --native-smoke')
            if not shutil.which('wtype'):
                raise SystemExit('wtype is required for the native keyboard-input check')
            bar = (ROOT/'modules/main/Bar.qml').read_text()
            binding = re.search(r'^\s*WlrLayershell.keyboardFocus:\s*(.+)$', bar, re.M)
            assert binding, 'Production bar must declare its native keyboard policy'
            policy = binding[1].strip().replace('barWindow.', 'host.')
            source = NATIVE_QML.replace('WlrLayershell.keyboardFocus: WlrKeyboardFocus.None // injected from the production bar binding', 'WlrLayershell.keyboardFocus: ' + policy)
            (target/'shell.qml').write_text(source)
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder)
        if options.native_smoke:
            env.update(QT_QPA_PLATFORM='wayland', XDG_RUNTIME_DIR=os.environ['XDG_RUNTIME_DIR'],
                       XDG_STATE_HOME=str(target/'state'), XDG_CACHE_HOME=str(target/'cache'))
        if options.capture_dir:
            env['RUSTICQ_UI_CAPTURE_DIR'] = str(Path(options.capture_dir).resolve())
        result = subprocess.run(['qs', '-p', str(target / 'shell.qml'), '--no-color'],
                                env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output, end='')
        pattern = r'NATIVE SEARCH RESULTS (\d+) passed, (\d+) failed' if options.native_smoke else r'WIFI AUDIO RESULTS (\d+) passed, (\d+) failed'
        summary = re.search(pattern, output)
        errors = re.search(r'(Binding loop|TypeError:|ReferenceError:|Error loading configuration)', output)
        minimum = 3 if options.native_smoke else 18
        return int(bool(result.returncode or not summary or int(summary[1]) < minimum or int(summary[2]) or errors))


if __name__ == '__main__':
    raise SystemExit(main())
