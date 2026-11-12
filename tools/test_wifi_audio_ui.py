#!/usr/bin/env python3
"""Offscreen Wi-Fi navigation and application audio controls with fake devices."""
import json
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture-dir', default='')
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
        interaction.write_text(interaction.read_text().replace('import "../services"', 'import "../services"\nimport "../fixtures"', 1))
        (target / 'user-settings.json').write_text('{}')
        (target / 'fixtures').mkdir()
        (target / 'fixtures/qmldir').write_text('singleton Pipewire 1.0 Pipewire.qml\nPwObjectTracker 1.0 PwObjectTracker.qml\nPwNodePeakMonitor 1.0 PwNodePeakMonitor.qml\nsingleton PwAudioChannel 1.0 PwAudioChannel.qml\n')
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
QtObject {
    property var wifiDevice: ({name: "wlan0"})
    property bool enabled: true
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
QtObject {
    property var wifiDevice: ({name: "wlan0", networks: []})
    property bool wifiEnabled: true
    property bool wifiHardwareEnabled: true
    property bool scanning: false
    property var processingNetwork: null
    function toggleScan() {}
    function toggleWifi() {}
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
        env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QPA_PLATFORMTHEME='generic',
                   QT_QUICK_BACKEND='software', XDG_RUNTIME_DIR=folder)
        if options.capture_dir:
            env['RUSTICQ_UI_CAPTURE_DIR'] = str(Path(options.capture_dir).resolve())
        result = subprocess.run(['qs', '-p', str(target / 'shell.qml'), '--no-color'],
                                env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output, end='')
        summary = re.search(r'WIFI AUDIO RESULTS (\d+) passed, (\d+) failed', output)
        errors = re.search(r'(Binding loop|TypeError:|ReferenceError:|Error loading configuration)', output)
        return int(bool(result.returncode or not summary or int(summary[1]) < 12 or int(summary[2]) or errors))


if __name__ == '__main__':
    raise SystemExit(main())
