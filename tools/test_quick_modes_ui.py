#!/usr/bin/env python3
"""Offscreen interaction tests with isolated settings and mocked desktop services."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    repo = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="quickshell-ui-test-") as folder:
        root = Path(folder)
        for name in ("components", "config", "services", "assets"):
            shutil.copytree(repo / name, root / name)
        (root / "tests").mkdir()
        shutil.copyfile(repo / "tools/QuickModesInteraction.qml", root / "tests/Interaction.qml")
        (root / "user-settings.json").write_text(json.dumps({
            "barMode": "clean-compact", "showNightMode": False, "showMicMute": False,
        }))
        fixtures = {
            "QuickModesService": '''
                property bool keepAwake: false
                property bool busy: false
                property string error: ""
                property bool anyActive: keepAwake
                function refresh() {}
                function active(key) { return key === "awake" && keepAwake; }
                function available(key) { return key !== "gaming"; }
                function detail(key) { return key; }
                function toggle(key) { if (key === "awake") keepAwake = !keepAwake; }
            ''',
            "BluetoothService": '''
                property bool connected: true
                property bool enabled: true
                property string icon: "\\ue1a8"
                property string deviceName: "Headphones"
            ''',
            "WifiService": '''
                property bool connected: true
                property bool enabled: true
                property string icon: "\\ue1d8"
                property string ssid: "Test network"
                property int strength: 80
            ''',
            "BatteryService": '''
                property bool available: true
                property bool charging: false
                property int percentage: 80
                property string icon: "\\ue1a4"
            ''',
        }
        for name, body in fixtures.items():
            (root / "services" / f"{name}.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject {\n" + body + "\n}\n")
        (root / "shell.qml").write_text('''
import QtQuick
import QtQuick.Window
import Quickshell
import "components"
import "tests"
ShellRoot {
    Window {
        visible: true
        width: 600
        height: 160
        Interaction { anchors.fill: parent }
    }
}
''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="generic",
                   QT_QUICK_BACKEND="software", XDG_RUNTIME_DIR=folder)
        result = subprocess.run(["qs", "-p", str(root / "shell.qml"), "--no-color"],
                                env=env, capture_output=True, text=True, timeout=25)
        output = result.stdout + result.stderr
        print(output, end="")
        summary = re.search(r"INTERACTION RESULTS (\d+) passed, (\d+) failed", output)
        if result.returncode or not summary or int(summary[1]) < 6 or int(summary[2]):
            return 1
        settings = json.loads((root / "user-settings.json").read_text())
        assert settings["barMode"] == "clean-compact"
        assert settings["showQuickModes"] is True
        for key in ("quickModesAutoHide", "showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute"):
            assert settings[key] is False, key
        print("PASS: settings load/save, hover, click, module visibility, indicator styling, and scan button")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
